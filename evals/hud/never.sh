#!/usr/bin/env bash
# What gku-hud never does, checked in its source: run it from anywhere.
#
#   bash evals/hud/never.sh
#
# gku-hud is a pane that reads .tasks/ and .gku/reports/ and puts a command in the
# prompt box for the person to send. Its README and manifest promise that it reads
# only: it writes no file, starts no turn, calls no model, adds nothing to the
# context, runs no process and opens no connection. Those are calls on `$`, so the
# promise holds exactly while the module's source makes none of them. This greps
# the module and everything it imports (hooks/ and src/, never tests/) for each
# one, spelled without the `$` so a noun taken off `$` first (`const { fs } = $`)
# is caught as well.
#
# Exits 0 when none is there, 1 otherwise, naming each file and line.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
hud="$root/plugins/gku-hud"
[ -d "$hud/hooks" ] || { printf 'no gku-hud hooks at %s\n' "$hud/hooks" >&2; exit 1; }

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }

# pattern|what it would break
while IFS='|' read -r pattern why; do
  [ -n "$pattern" ] || continue
  hits="$(grep -rnE --include='*.ts' --include='*.tsx' -e "$pattern" "$hud/hooks" "$hud/src" 2>/dev/null)"
  [ -z "$hits" ] || note "$why: ${hits//$root\//}"
done <<'EOF_RULES'
fs\.write|writes a file
prompt\.submit|starts a turn on its own
\bmodel\.|calls a model
prompt\.compose|adds to the system prompt
prompt\.context|adds to the context
\bprocess\.(run|spawn)|runs a process
\bhttp\.|opens a connection
\bstore\.set|keeps data across sessions
EOF_RULES

# The source the module reads at all: a check of nothing passes vacuously.
n="$(find "$hud/hooks" "$hud/src" \( -name '*.ts' -o -name '*.tsx' \) | wc -l | tr -d ' ')"
[ "$n" -ge 3 ] || note "only $n source files under hooks/ and src/: the check would be vacuous"
grep -q 'prompt\.fill' "$hud/hooks/register.tsx" || note 'register.tsx no longer fills the prompt: the pane offers its commands some other way'

if [ "$fails" -eq 0 ]; then
  printf 'hud-never: gku-hud reads only — no write, submit, model, context, process, connection or store call in %s files\n' "$n"
else
  printf 'hud-never: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
