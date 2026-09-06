#!/usr/bin/env bash
# The evidence gate, asserted: run it from anywhere.
#
#   bash evals/reference/claims.sh
#
# reference/exec.md is read by every skill that runs a project command, and it
# carries one rule the skills would otherwise each restate: a claim needs output
# from this turn. What is checked here is that the rule is still in the file, and
# that the four skills which report results still point at it — a pointer is what
# makes a shared rule cheaper than four copies of it.
#
# Exits 0 when both hold, 1 otherwise.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
exec_md="$root/plugins/gku/reference/exec.md"
skills="$root/plugins/gku/skills"
[ -f "$exec_md" ] || { printf 'no exec.md at %s\n' "$exec_md" >&2; exit 1; }

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }

grep -q '^## Claims need fresh evidence' "$exec_md" || note 'exec.md has lost the evidence gate'
grep -q 'output' "$exec_md" || note 'exec.md: the gate should say what counts as evidence'

# Short on purpose: it is read at the first step of every skill that runs a command.
lines="$(wc -l < "$exec_md" | tr -d ' ')"
[ "$lines" -le 80 ] || note "exec.md is $lines lines; every skill reads it first, so keep it under 80"

for s in implement fix verify pr; do
  f="$skills/$s/SKILL.md"
  [ -f "$f" ] || { note "$s: no SKILL.md"; continue; }
  grep -q 'exec.md' "$f" || note "$s: reports results but never points at reference/exec.md"
done

if [ "$fails" -eq 0 ]; then
  printf 'claims: the evidence gate is in exec.md and the four reporting skills point at it\n'
else
  printf 'claims: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
