#!/usr/bin/env bash
# The plan is the scope, asserted: run it from anywhere.
#
#   bash evals/skills/scope.sh
#
# The failure this guards against is a run that wanders: /gku:implement notices
# something beside its edit, fixes it, then refactors around the fix, and ends far
# from the plan it was given — or keeps going after the last step because a new
# idea arrived. So three things have to stay in implement's prose: the sort into
# blocker / plan change / note, the one question that separates a blocker from a
# note, and the end of the run. /gku:plan writes a "Do not touch" list that only
# implement can honour, and /gku:fix has the same rule for its own loop.
#
# Exits 0 when they hold, 1 otherwise.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
skills="$root/plugins/gku/skills"
[ -d "$skills" ] || { printf 'no skills at %s\n' "$skills" >&2; exit 1; }

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
# Prose wrapped at the file's width: match against a flattened copy, as
# evals/reference/claims.sh does.
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }

imp="$skills/implement/SKILL.md"
[ -f "$imp" ] || { printf 'no implement/SKILL.md\n' >&2; exit 1; }
impf="$(flat "$imp")"

# The sort itself. Three branches, and the middle one is the one that gets lost:
# an approach that cannot work is a stop-and-ask, not something to build around.
printf '%s' "$impf" | grep -q 'The plan is the scope' || note 'implement: nothing says the plan is the scope'
printf '%s' "$impf" | grep -q 'A blocker is demonstrated, not suspected' || note 'implement: a blocker is whatever the run calls one, so everything can be one'
printf '%s' "$impf" | grep -qi 'no longer reaches its goal' || note 'implement: no branch for a plan that cannot reach its goal'
printf '%s' "$impf" | grep -q 'write the new steps' || note 'implement: adjusts the plan in the chat, where --continue cannot read it'

# The test between fixing it and noting it. Without a single question the sort is
# three labels the run applies to whatever it already wanted to do.
printf '%s' "$impf" | grep -q 'does an acceptance criterion fail without it' || note 'implement: no test separating a blocker from a nice-to-have'

# The plan's own out-of-scope list: /gku:plan writes it, implement is the only
# skill that can act on it.
grep -q '^## Do not touch' "$skills/plan/SKILL.md" || note 'plan: the template no longer writes a "Do not touch" list'
printf '%s' "$impf" | grep -q '`Do not touch` list' || note 'implement: ignores the "Do not touch" list a plan writes, so writing it buys nothing'

# The end of the run. A finished plan that keeps absorbing work is the same drift
# arriving one step later.
printf '%s' "$impf" | grep -q 'the plan is done' || note 'implement: never says the run has ended'
printf '%s' "$impf" | grep -q 'start of a new plan' || note 'implement: leftovers have nowhere to go but this run'

# /gku:fix applies a list rather than a plan, and needs the same rule in its loop.
printf '%s' "$(flat "$skills/fix/SKILL.md")" | grep -q 'Do not refactor nearby code' || note 'fix: drive-by refactors are back'

if [ "$fails" -eq 0 ]; then
  printf 'scope: implement sorts what it finds, honours "Do not touch", and ends when the plan does\n'
else
  printf 'scope: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
