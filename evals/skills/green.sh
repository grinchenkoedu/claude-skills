#!/usr/bin/env bash
# Green for the right reason, asserted: run it from anywhere.
#
#   bash evals/skills/green.sh
#
# A model trained on pass/fail rewards reaches green the cheapest way: it loosens
# the assertion that failed, or wraps the error in a catch that swallows it. Two
# halves keep that visible. implement and fix forbid it in their rules, and say
# a silenced check counts the same as a weakened test. review flags both patterns
# in your own diff, and --auto's self-review looks for them, because a self-review
# is the one review an unattended run gets. A reason clears a finding only where
# review can read it, and under --auto only when a criterion names the change.
#
# Exits 0 when both halves hold, 1 otherwise.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
skills="$root/plugins/gku/skills"
[ -d "$skills" ] || { printf 'no skills at %s\n' "$skills" >&2; exit 1; }

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
# Prose wrapped at the file's width: match against a flattened copy, as
# evals/reference/claims.sh does.
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }

# The rule, in the two skills that write code to get a suite green.
for s in implement fix; do
  f="$(flat "$skills/$s/SKILL.md")"
  printf '%s' "$f" | grep -q 'Never weaken or delete an existing test to get to green' || note "$s: nothing forbids weakening a test to get to green"
  printf '%s' "$f" | grep -q 'makes it quiet, not right' || note "$s: a suppression or a swallowing catch is not covered by the rule"
  printf '%s' "$f" | grep -q 'looks for the reason' || note "$s: the reason for changing a test has no place review reads"
done

# The reviewer's half: an edited test and a silenced check are findings.
rev="$(flat "$skills/review/SKILL.md")"
printf '%s' "$rev" | grep -q 'An existing test edited to pass' || note 'review: judges new tests only, so a loosened existing assertion passes unseen'
printf '%s' "$rev" | grep -q 'a red suite is not' || note 'review: an edited test is not checked for a stated reason'
printf '%s' "$rev" | grep -q 'unless the reason is on record' || note 'review: a reason recorded as a Ruling: does not clear an edited test'
printf '%s' "$rev" | grep -q 'a check silenced instead of satisfied' || note 'review: a swallowing catch or a suppression is not a finding'

# The unattended run reviews itself, so it has to look for the same two things.
impf="$(flat "$skills/implement/SKILL.md")"
printf '%s' "$impf" | grep -q 'goes green without being right' || note 'implement: the --auto self-review does not look for an edited test or a silenced check'
printf '%s' "$impf" | grep -q 'only when an acceptance criterion names the behaviour' ||
  note 'implement: an --auto run can clear its own edited test with a Ruling: it wrote'

if [ "$fails" -eq 0 ]; then
  printf 'green: implement and fix forbid gaming a check, review and --auto look for it\n'
else
  printf 'green: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
