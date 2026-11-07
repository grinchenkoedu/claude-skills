#!/usr/bin/env bash
# Cases for plugins/gku/bin/gku-agents — run them from anywhere:
#
#   bash evals/agents/cases.sh
#
# gku-agents lists the agent CLIs a review may hand a second opinion to. What is
# checked: each supported agent is listed when it is on the PATH and only then,
# an agent gku does not know how to run read-only is never listed, and nothing
# installed prints nothing, and so does a checkout that turned the offer off with
# .gku/no-second-opinion at its primary root — from a linked worktree too. Each
# case runs on a PATH of stub binaries plus the system directories, so the agents
# really installed here do not leak in.
#
# Exits 0 when every case matches, 1 otherwise, naming each mismatch.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
agents="${GKU_AGENTS:-$root/plugins/gku/bin/gku-agents}"
[ -x "$agents" ] || { printf 'no executable gku-agents at %s\n' "$agents" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM

fails=0 cwd=""   # cwd: where gku-agents runs; empty is this suite's own directory
case_() { # case_ <label> <expected output, \n-separated> <stub names…>
  local label="$1" want="$2" dir got; shift 2
  dir="$work/$label"; mkdir -p "$dir"
  for s in "$@"; do printf '#!/bin/sh\nexit 0\n' > "$dir/$s"; chmod +x "$dir/$s"; done
  got="$(cd "${cwd:-$PWD}" && PATH="$dir:/usr/bin:/bin" /bin/bash "$agents" 2>&1)"
  want="$(printf '%b' "$want" | sed "s|@|$dir/|g")"
  if [ "$got" != "$want" ]; then
    printf 'FAIL  %s\n  want: %s\n  got:  %s\n' "$label" "$(printf '%s' "$want" | tr '\n' '|')" \
      "$(printf '%s' "$got" | tr '\n' '|')"
    fails=$((fails + 1))
  fi
}

case_ none        ''                                           # nothing installed
case_ agy         'agy: @agy'                                   agy
case_ copilot     'copilot: @copilot'                           copilot
case_ opencode    'opencode: @opencode'                         opencode
case_ gemini      ''                                            gemini
case_ unknown     ''                                            codex aider
case_ all         'agy: @agy\ncopilot: @copilot\nopencode: @opencode' agy copilot opencode gemini codex

# The marker: a checkout with .gku/no-second-opinion at its primary root offers nothing, and a
# linked worktree of it reads the marker there, as the hooks read .gku/auto-run.
repo="$work/repo"; mkdir -p "$repo"
git -C "$repo" -c user.name=eval -c user.email=eval@example.invalid init -q .
cwd="$repo"
case_ no-marker   'agy: @agy'                                   agy
mkdir -p "$repo/.gku"; : > "$repo/.gku/no-second-opinion"
case_ marker      ''                                            agy copilot opencode
git -C "$repo" -c user.name=eval -c user.email=eval@example.invalid commit -q --allow-empty -m seed
git -C "$repo" worktree add -q "$work/tree" -b other
cwd="$work/tree"
case_ marker-from-worktree '' agy
cwd=""

if [ "$fails" -eq 0 ]; then
  printf 'agents: every case lists what it should\n'
else
  printf 'agents: %s case(s) wrong\n' "$fails" >&2
fi
exit $((fails > 0))
