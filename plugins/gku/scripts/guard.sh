#!/usr/bin/env bash
# The gku guard — a PreToolUse hook on Bash. /gku:implement, /gku:fix, /gku:pr
# and /gku:pr-resolve register it when they are invoked, and Claude Code keeps
# it for the rest of the session, on later turns as well.
#
# Reads the hook's JSON on stdin, looks at tool_input.command, and refuses
# (exit 2, reason on stderr) what the Rules of those four skills forbid in prose:
#   git push --force / --force-with-lease / -f
#   git commit --amend
#   --no-verify on any git command
#   git push to the base branch (main, master, or the profile's baseBranch)
#   gh pr review --approve — the run that wrote a change is not its reviewer
# and, while an unattended run is in progress, the commands that end or ship a
# change rather than propose one:
#   gh pr merge, gh release, gh workflow run, gh api ... /merge
# `.gku/auto-run` is what makes a run unattended: /gku:implement --auto writes
# it and removes it when the run ends. Without that file a person is watching,
# and a merge they ask for is theirs to ask for — the guard stays out of it, as
# reference/untrusted-input.md already says it should: only the developer,
# typing in the conversation, lifts one of these.
# Everything else exits 0 and the command runs.
#
# Ported from claude-rpg's plugins/rpg/scripts/guard.sh — MIT, same author
# (Yevhen Matasar), reworded for gku's vocabulary.

input="$(cat)"

has_jq=""
command -v jq >/dev/null 2>&1 && has_jq=1

# The sed fallback takes -E, because BSD sed has no \| alternation in a basic
# regex and would silently extract nothing — a guard that refuses nothing.
field() { # field <key> <jq path> — that JSON string value, jq where there is jq
  if [ -n "$has_jq" ]; then
    printf '%s' "$input" | jq -r "$2 // empty" 2>/dev/null
  else
    printf '%s' "$input" | sed -E -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -1
  fi
}

cmd="$(field command '.tool_input.command')"
[ -n "$cmd" ] || exit 0
case "$cmd" in *git*|*gh*) ;; *) exit 0 ;; esac

# The payload names the session's directory; the hook's own cwd need not be the
# project, and a profile — or a marker — read from the wrong place is neither.
hook_cwd="$(field cwd '.cwd')"

refuse() { printf 'The gku guard refuses: %s\n' "$1" >&2; exit 2; }

# Match against the command with quoted text blanked out: a commit message
# that names a flag — git commit -m "never pass --no-verify" — is talk about
# the flag, not use of it. Everything outside the quotes survives, so the
# flags themselves are still seen.
scan="$(printf '%s' "$cmd" | sed -E "s/'[^']*'/''/g; s/\"[^\"]*\"/\"\"/g")"

if printf '%s' "$scan" | grep -Eq 'git[^|;&]*push[^|;&]*(--force|--force-with-lease|(^|[[:space:]])-f([[:space:]]|$))'; then
  refuse "a forced push rewrites history somebody else may have. Push a new commit instead."
fi
if printf '%s' "$scan" | grep -Eq 'git[^|;&]*commit[^|;&]*--amend'; then
  refuse "--amend rewrites the last commit. Make a new commit instead."
fi
if printf '%s' "$scan" | grep -Eq 'git[^|;&]*--no-verify'; then
  refuse "--no-verify skips a hook. A failing hook means the code needs fixing."
fi

# Approving is refused in either mode, because no marker makes it sound: the run
# that wrote the change would be signing off its own work.
if printf '%s' "$scan" | grep -Eq 'gh[^|;&]*pr[^|;&]*[[:space:]]--approve([[:space:]]|$)'; then
  refuse "approving is a reviewer's act. A run that wrote the change cannot also approve it."
fi

# Merging and shipping are where an unattended run stops. The word has to end
# where it is matched, so --json mergeable stays a question and `gh pr merge`
# is a merge.
ship=""
if printf '%s' "$scan" | grep -Eq 'gh[^|;&]*pr[^|;&]*[[:space:]]merge([[:space:]]|$)'; then
  ship="merging ends a change"
elif printf '%s' "$scan" | grep -Eq 'gh[^|;&]*release[[:space:]]+(create|edit|delete|upload)([[:space:]]|$)'; then
  ship="a release ships to users"
elif printf '%s' "$scan" | grep -Eq 'gh[^|;&]*workflow[[:space:]]+(run|enable|disable)([[:space:]]|$)'; then
  ship="running a workflow reaches CI and whatever it deploys"
elif printf '%s' "$scan" | grep -Eq 'gh[^|;&]*api[^|;&]*/merge'; then
  ship="that API call merges"
fi
if [ -n "$ship" ]; then
  # The marker sits at the root of the primary repository, or in the session's
  # directory when that is not a checkout. --git-common-dir, not
  # --show-toplevel: in a worktree the latter is the worktree's own root, and
  # the run that wrote the marker used the primary one (reference/reports.md).
  dir="${hook_cwd:-$PWD}"
  root=""
  # Resolve the common dir first: empty means no checkout here, and cd-ing to
  # "/.." on the way past would silently land on the filesystem root.
  common="$(cd "$dir" 2>/dev/null && git rev-parse --git-common-dir 2>/dev/null)"
  [ -n "$common" ] && root="$(cd "$dir" && cd "$common/.." 2>/dev/null && pwd)"
  marker="${root:-$dir}/.gku/auto-run"
  if [ -f "$marker" ]; then
    refuse "$ship, and nobody is watching this run — $marker says it is unattended. Opening the pull request is where it stops; if that run is over, remove that file."
  fi
fi

base=""
if [ -n "$has_jq" ]; then
  profile="${hook_cwd:+$hook_cwd/}.claude/repo-profile.json"
  [ -f "$profile" ] && base="$(jq -r '.baseBranch // empty' "$profile" 2>/dev/null)"
fi
# The ref can arrive after a space or after a colon (HEAD:main), carry a
# leading + (which is itself a forced push), and spell itself out in full
# (refs/heads/main). All four shapes push to the same branch.
for b in main master ${base:+"$base"}; do
  # A branch name is a literal here, not a pattern: release.1 must not also
  # match release01.
  b_re="$(printf '%s' "$b" | sed -E 's|[^a-zA-Z0-9_/-]|\\&|g')"
  if printf '%s' "$scan" | grep -Eq "git[^|;&]*push[^|;&]*([[:space:]]|:)\+?(refs/heads/)?$b_re([[:space:]]|:|\$)"; then
    refuse "a push to the base branch '$b'. A change lands through a pull request — /gku:pr opens it."
  fi
done

exit 0
