#!/usr/bin/env bash
# Cases for plugins/gku/bin/gku-agents — run them from anywhere:
#
#   bash evals/agents/cases.sh
#
# gku-agents lists the agent CLIs a review may hand a second opinion to. What is
# checked: each supported agent is listed when it is on the PATH and only then,
# an agent gku does not know how to run read-only is never listed, and nothing
# installed prints nothing. Each case runs on a PATH of stub binaries plus the
# system directories, so the agents really installed here do not leak in.
#
# Exits 0 when every case matches, 1 otherwise, naming each mismatch.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
agents="${GKU_AGENTS:-$root/plugins/gku/bin/gku-agents}"
[ -x "$agents" ] || { printf 'no executable gku-agents at %s\n' "$agents" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM

fails=0
case_() { # case_ <label> <expected output, \n-separated> <stub names…>
  local label="$1" want="$2" dir got; shift 2
  dir="$work/$label"; mkdir -p "$dir"
  for s in "$@"; do printf '#!/bin/sh\nexit 0\n' > "$dir/$s"; chmod +x "$dir/$s"; done
  got="$(PATH="$dir:/usr/bin:/bin" /bin/bash "$agents" 2>&1)"
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

if [ "$fails" -eq 0 ]; then
  printf 'agents: every case lists what it should\n'
else
  printf 'agents: %s case(s) wrong\n' "$fails" >&2
fi
exit $((fails > 0))
