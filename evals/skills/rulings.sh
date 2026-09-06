#!/usr/bin/env bash
# The ruling line, asserted: run it from anywhere.
#
#   bash evals/skills/rulings.sh
#
# A ruling is a decision a skill made without asking — where a class went, which
# of two fixes it took. Writing it down is only half of it: the value is that
# /gku:review reads them back and checks each against the diff. Both halves have
# to stay, or the line becomes a note nobody reads.
#
# Exits 0 when they do, 1 otherwise.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
skills="$root/plugins/gku/skills"
[ -d "$skills" ] || { printf 'no skills at %s\n' "$skills" >&2; exit 1; }

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
# Prose wrapped at the file's width: match against a flattened copy, as
# evals/reference/claims.sh does.
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }

for s in implement fix; do
  f="$skills/$s/SKILL.md"
  grep -q 'Ruling:' "$f" || note "$s: decides things on its own but records no ruling"
  flat "$f" | grep -q 'costs if wrong' || note "$s: a ruling without its cost is half a ruling"
done

f="$skills/review/SKILL.md"
grep -q 'Ruling:' "$f" || note 'review: never reads the rulings, so writing them buys nothing'
flat "$f" | grep -q 'check each against the diff' || note 'review: reads the rulings but does not check them'

if [ "$fails" -eq 0 ]; then
  printf 'rulings: implement and fix record them, review checks them\n'
else
  printf 'rulings: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
