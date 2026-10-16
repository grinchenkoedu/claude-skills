#!/usr/bin/env bash
# Steps in working slices, asserted: run it from anywhere.
#
#   bash evals/skills/slices.sh
#
# A plan built layer by layer — every table, then every class, then every page —
# cannot be checked until its last step lands, and each step before it is proved
# only by its own unit test. /gku:plan orders the steps so each one leaves
# something that runs, and keeps the obvious order for a change that is one layer.
#
# Exits 0 when that holds, 1 otherwise.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
plan="$root/plugins/gku/skills/plan/SKILL.md"
[ -f "$plan" ] || { printf 'no plan/SKILL.md at %s\n' "$plan" >&2; exit 1; }

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
# Prose wrapped at the file's width: match against a flattened copy, as
# evals/reference/claims.sh does.
plf="$(tr '\n' ' ' < "$plan" | tr -s ' ')"

printf '%s' "$plf" | grep -q 'each one leaves something that runs' || note 'plan: steps may be ordered layer by layer, unchecked until the last'
printf '%s' "$plf" | grep -q 'keeps its obvious order' || note 'plan: a one-layer change is forced into slices it does not have'

if [ "$fails" -eq 0 ]; then
  printf 'slices: plan orders steps so each leaves something that runs\n'
else
  printf 'slices: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
