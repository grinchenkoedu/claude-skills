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
# These files are prose wrapped at the width of the file, so a two-word phrase is
# as likely to straddle a line break as not — and the continuation line may be
# indented. Match against a copy with the newlines and runs of spaces squeezed out.
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }

grep -q '^## Claims need fresh evidence' "$exec_md" || note 'exec.md has lost the evidence gate'
flat "$exec_md" | grep -q 'in this turn' || note "exec.md: the gate has lost its point — evidence is output from this turn"

# Short on purpose: it is read at the first step of every skill that runs a command.
lines="$(wc -l < "$exec_md" | tr -d ' ')"
[ "$lines" -le 80 ] || note "exec.md is $lines lines; every skill reads it first, so keep it under 80"

# The pointer, not the filename: three of these four read exec.md at step 1 and so
# mention it whatever they do about claims, which would make a bare filename check
# pass on prose that predates the gate entirely.
for s in implement fix verify pr; do
  f="$skills/$s/SKILL.md"
  [ -f "$f" ] || { note "$s: no SKILL.md"; continue; }
  flat "$f" | grep -q 'fresh evidence' || note "$s: reports results without pointing at the gate ('fresh evidence')"
done

if [ "$fails" -eq 0 ]; then
  printf 'claims: the evidence gate is in exec.md and the four reporting skills point at it\n'
else
  printf 'claims: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
