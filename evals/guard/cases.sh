#!/usr/bin/env bash
# Behaviour cases for plugins/gku/scripts/guard.sh — run them from anywhere:
#
#   bash evals/guard/cases.sh
#
# Every case is "expected exit code | the command the hook is asked about".
# Each table runs twice: once as the machine is, and once with jq off the PATH,
# because the guard's jq-less fallback is the half that silently refused
# nothing when its regex was wrong. The second table runs the shipping commands
# again with .gku/auto-run in place, which is the whole difference between a run
# a person is watching and one nobody is.
#
# Exits 0 when every case matches, 1 otherwise, naming each mismatch.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
guard="$root/plugins/gku/scripts/guard.sh"
[ -x "$guard" ] || { printf 'no guard at %s\n' "$guard" >&2; exit 1; }

# A directory with no profile in it, so only main and master are base branches
# and the result does not depend on whose checkout this is.
work="$(mktemp -d)"
# The jq-less PATH: the tools the guard needs, and not jq.
nojq="$work/nojq"; mkdir -p "$nojq"
for t in cat sed grep head git; do
  for c in /bin/$t /usr/bin/$t; do [ -x "$c" ] && ln -sf "$c" "$nojq/$t" && break; done
done

fails=0
run() { # run <label> <expected> <json-escaped command> [PATH] [cwd]
  local label="$1" want="$2" cmd="$3" path="${4-}" here="${5-$work}" got where=""
  if [ -n "$path" ]; then
    ( cd "$here" && printf '{"cwd":"%s","tool_input":{"command":"%s"}}' "$here" "$cmd" | PATH="$path" /bin/bash "$guard" ) >/dev/null 2>&1
  else
    ( cd "$here" && printf '{"cwd":"%s","tool_input":{"command":"%s"}}' "$here" "$cmd" | "$guard" ) >/dev/null 2>&1
  fi
  got=$?
  [ "$here" = "$work" ] || where="  [cwd ${here#"$work"/}]"
  if [ "$got" != "$want" ]; then
    printf 'FAIL  %-10s want=%s got=%s  %s%s\n' "$label" "$want" "$got" "$cmd" "$where"
    fails=$((fails + 1))
  fi
}

cases() {
  local label="$1" path="${2-}"
  while IFS='|' read -r want cmd; do
    case "$want" in ''|'#'*) continue ;; esac
    run "$label" "$want" "$cmd" "$path"
  done <<'TABLE'
# refused — a forced push, however it is spelled
2|git push --force origin x
2|git push --force-with-lease
2|git push -f origin x
2|cd sub && git push --force
# refused — rewriting or skipping
2|git commit --amend -m \"x\"
2|git commit --no-verify -m \"x\"
2|git push --no-verify
# refused — a push to the base branch, in each of its shapes
2|git push origin main
2|git push -u origin master
2|git push origin HEAD:main
2|git push origin master:master
2|git push origin +main
2|git push origin HEAD:refs/heads/main
2|git push origin +refs/heads/master
2|git push --delete origin main
# allowed — an ordinary branch whose name merely contains one
0|git push origin feature/x
0|git push origin feature/main-thing
0|git push origin main-thing
0|git push origin domain
# allowed — talk about a flag is not use of it
0|git commit -m \"never pass --no-verify\"
0|git commit -m \"push --force is banned here\"
0|git commit -m 'do not --amend'
# allowed — and the flags outside the quotes are still seen
2|git commit -m \"msg\" && git push --force
# refused whoever is watching — the run that wrote a change is not its reviewer
2|gh pr review 12 --approve
# allowed — no .gku/auto-run, so a person is watching and what they ask for is
# theirs to ask for
0|gh pr merge 12
0|gh pr merge --squash --delete-branch 12
0|gh pr merge --admin
0|gh release create v1.2.0
0|gh release upload v1.2.0 dist.zip
0|gh workflow run deploy.yml
0|gh api repos/o/r/pulls/12/merge -X PUT
# allowed — the gh a skill actually needs, including the ones that say merge
0|gh pr create --base main --head x
0|gh pr ready 12
0|gh pr view 12 --json mergeable,mergeStateStatus
0|gh pr list --search \"merge conflict\"
0|gh pr comment 12 --body \"this needs a merge from main\"
0|gh repo view --json isPrivate
0|gh api repos/o/r/pulls/12/comments
# allowed — nothing to do with git, or nothing to read
0|ls -la
0|rm -rf build
TABLE
}

# The same commands with an unattended run in progress: /gku:implement --auto
# writes .gku/auto-run for as long as it runs, and nobody is reading what that
# run does — so the commands that end or ship a change stop there.
auto_cases() {
  local label="$1" path="${2-}"
  while IFS='|' read -r want cmd; do
    case "$want" in ''|'#'*) continue ;; esac
    run "$label" "$want" "$cmd" "$path"
  done <<'TABLE'
# refused — ending or shipping a change, with nobody watching
2|gh pr merge 12
2|gh pr merge --squash --delete-branch 12
2|gh release create v1.2.0
2|gh workflow run deploy.yml
2|gh api repos/o/r/pulls/12/merge -X PUT
# allowed — proposing one is what an unattended run is for
0|gh pr create --base main --head x
0|gh pr ready 12
0|gh pr view 12 --json mergeable,mergeStateStatus
# refused either way, so the marker cannot be read as the only thing holding
2|git push --force origin x
2|git push origin main
TABLE
}

# The marker in a real checkout. The tables run from a bare temp directory,
# where every way of resolving a repository root falls back to the directory
# itself — so they cannot tell --show-toplevel from --git-common-dir, and a
# guard that reads the marker in the worktree instead of the primary checkout
# passes them while letting an unattended run ship. These cases can.
repo_cases() {
  local label="$1" path="${2-}" repo="$work/repo" d
  git init -q "$repo" 2>/dev/null || { printf 'SKIP  %-10s no git\n' "$label"; return; }
  git -C "$repo" -c user.email=eval@example.invalid -c user.name=eval \
    commit -q --allow-empty -m root 2>/dev/null
  mkdir -p "$repo/sub" "$repo/.gku"
  printf 'started at eval time in session eval\n' > "$repo/.gku/auto-run"
  git -C "$repo" worktree add -q "$work/wt" HEAD 2>/dev/null
  # The marker lives at the primary root; the run may be anywhere under it.
  for d in "$repo" "$repo/sub" "$work/wt"; do
    [ -d "$d" ] && run "$label" 2 'gh pr merge 12' "$path" "$d"
  done
  # And gone means gone, from the same three places.
  rm -f "$repo/.gku/auto-run"
  for d in "$repo" "$repo/sub" "$work/wt"; do
    [ -d "$d" ] && run "$label" 0 'gh pr merge 12' "$path" "$d"
  done
  git -C "$repo" worktree remove --force "$work/wt" 2>/dev/null
  rm -rf "$repo" "$work/wt"
}

cases 'jq'
[ -x "$nojq/sed" ] && cases 'no-jq' "$nojq"

mkdir -p "$work/.gku" && printf 'started 2026-09-09T00:00:00Z in session eval\n' > "$work/.gku/auto-run"
auto_cases 'jq-auto'
[ -x "$nojq/sed" ] && auto_cases 'no-jq-auto' "$nojq"
rm -f "$work/.gku/auto-run"

repo_cases 'jq-repo'
[ -x "$nojq/git" ] && repo_cases 'no-jq-repo' "$nojq"

rm -rf "$work"
if [ "$fails" -eq 0 ]; then
  printf 'guard: all cases pass\n'
else
  printf 'guard: %s case(s) failed\n' "$fails" >&2
fi
exit $((fails > 0))
