#!/usr/bin/env bash
# Red before green, asserted: run it from anywhere.
#
#   bash evals/skills/red-first.sh
#
# A test written after the fix passes whether or not it would have caught the
# bug, so a green result beside a fix proves the test runs, not that it tests
# anything. Two skills fix bugs. fix writes the test first when one can show the
# finding, watches it fail for the finding's own reason, and reports the failing
# line beside the passing one; when no test can, its reproduction is the proof.
# implement treats a task file of Type: bug as test-first, and its test-first
# order already demands the failure before the code.
#
# Exits 0 when both hold, 1 otherwise.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
skills="$root/plugins/gku/skills"
for s in fix implement; do
  [ -f "$skills/$s/SKILL.md" ] || { printf 'no %s/SKILL.md under %s\n' "$s" "$skills" >&2; exit 1; }
done

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
# Prose wrapped at the file's width, and dressed in backticks and bold: flatten
# and undress before matching, as evals/skills/manual.sh does.
flat() { tr '\n' ' ' < "$1" | tr -d '`*' | tr -s ' '; }
has() { printf '%s' "$1" | grep -qF -e "$2"; }

fixf="$(flat "$skills/fix/SKILL.md")"
impf="$(flat "$skills/implement/SKILL.md")"

# fix: the test comes first, and its failure has to be the right one.
has "$fixf" 'Make it fail first, when a test can show it' \
  || note 'fix: a finding is fixed before any test has shown it'
has "$fixf" 'for the reason the finding describes' \
  || note 'fix: any failure counts, so a typo in the test passes for proof'
has "$fixf" 'A test that passes before the fix proves nothing' \
  || note 'fix: a test that was green before the fix is accepted'
# The way round, for a bug no test can show: the reproduction, run twice — and
# when there was none, saying so rather than claiming a proof that never ran.
has "$fixf" 'When step 3 ran, its reproduction, run again after the fix, is then the proof' \
  || note 'fix: a bug no test can show is left with no proof at all'
has "$fixf" 'is fixed with nothing beyond the suite to prove it' \
  || note 'fix: a finding with no test and no reproduction is reported as proven'
has "$fixf" 'the test from 2 now passes' \
  || note 'fix: the red test is never seen to turn green'
has "$fixf" 'failing line from before the fix beside its passing line after' \
  || note 'fix: the report quotes the green line only, which proves nothing about the bug'

# implement: a bug task is test-first, and test-first means red first.
has "$impf" "the task file's Type: is bug" \
  || note 'implement: a task file of Type: bug is built and covered after, never shown red'
has "$impf" 'it has to fail, and fail for the right reason' \
  || note 'implement: test-first order no longer demands the failure before the code'

if [ "$fails" -eq 0 ]; then
  printf 'red-first: fix and implement show a bug-fix test failing before it passes\n'
else
  printf 'red-first: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
