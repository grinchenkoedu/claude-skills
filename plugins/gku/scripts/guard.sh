#!/usr/bin/env bash
# The gku guard — a PreToolUse hook on Bash, registered while a writing skill runs.
#
# Reads the hook's JSON on stdin, looks at tool_input.command, and refuses
# (exit 2, reason on stderr) the four things the Rules of /gku:implement,
# /gku:fix, /gku:pr and /gku:pr-resolve forbid in prose:
#   git push --force / --force-with-lease / -f
#   git commit --amend
#   --no-verify on any git command
#   git push to the base branch (main, master, or the profile's baseBranch)
# and the gh commands that end or ship a change rather than propose one:
#   gh pr merge, gh pr review --approve, gh release, gh workflow run,
#   gh api ... /merge
# Everything else exits 0 and the command runs — gh pr ready included, which
# /gku:pr offers deliberately when the work behind a draft is finished.
#
# Ported from claude-rpg's plugins/rpg/scripts/guard.sh — MIT, same author
# (Yevhen Matasar), reworded for gku's vocabulary.

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
else
  # -E, because BSD sed has no \| alternation in a basic regex and would
  # silently extract nothing — a guard that refuses nothing.
  cmd="$(printf '%s' "$input" | sed -E -n 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -1)"
fi

[ -n "$cmd" ] || exit 0
case "$cmd" in *git*|*gh*) ;; *) exit 0 ;; esac

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

base=""
if command -v jq >/dev/null 2>&1; then
  # The payload names the session's directory; the hook's own cwd need not be
  # the project, and a profile read from the wrong place is no profile at all.
  hook_cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
  profile="${hook_cwd:+$hook_cwd/}.claude/repo-profile.json"
  [ -f "$profile" ] && base="$(jq -r '.baseBranch // empty' "$profile" 2>/dev/null)"
fi
# The ref can arrive after a space or after a colon (HEAD:main), carry a
# leading + (which is itself a forced push), and spell itself out in full
# (refs/heads/main). All four shapes push to the same branch.
# Merging and shipping are where every skill here stops, including a run given
# --auto, which pushes and opens a pull request with nobody watching. The word
# has to end there — --json mergeable is a question, not a merge.
if printf '%s' "$scan" | grep -Eq 'gh[^|;&]*pr[^|;&]*[[:space:]]merge([[:space:]]|$)'; then
  refuse "merging is where this stops. Open or update the pull request; a person merges it."
fi
if printf '%s' "$scan" | grep -Eq 'gh[^|;&]*pr[^|;&]*[[:space:]]--approve([[:space:]]|$)'; then
  refuse "approving is a reviewer's act. A run that wrote the change cannot also approve it."
fi
if printf '%s' "$scan" | grep -Eq 'gh[^|;&]*release[[:space:]]+(create|edit|delete|upload)([[:space:]]|$)'; then
  refuse "a release ships to users. That is a decision a person makes, after the merge."
fi
if printf '%s' "$scan" | grep -Eq 'gh[^|;&]*workflow[[:space:]]+(run|enable|disable)([[:space:]]|$)'; then
  refuse "running a workflow reaches CI and whatever it deploys. Ask before triggering it."
fi
if printf '%s' "$scan" | grep -Eq 'gh[^|;&]*api[^|;&]*/merge'; then
  refuse "that API call merges. Opening the pull request is where this stops."
fi

for b in main master ${base:+"$base"}; do
  # A branch name is a literal here, not a pattern: release.1 must not also
  # match release01.
  b_re="$(printf '%s' "$b" | sed -E 's|[^a-zA-Z0-9_/-]|\\&|g')"
  if printf '%s' "$scan" | grep -Eq "git[^|;&]*push[^|;&]*([[:space:]]|:)\+?(refs/heads/)?$b_re([[:space:]]|:|\$)"; then
    refuse "a push to the base branch '$b'. A change lands through a pull request — /gku:pr opens it."
  fi
done

exit 0
