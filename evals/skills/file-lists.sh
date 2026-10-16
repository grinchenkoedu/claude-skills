#!/usr/bin/env bash
# The per-step file lists, asserted: run it from anywhere.
#
#   bash evals/skills/file-lists.sh
#
# Three skills write plans and two read them. The lists are only worth writing
# because something reads them: /gku:implement opens the Modify: paths instead of
# searching the repository, and /gku:review greps them for symbols that moved. If
# either half goes, the lists become decoration in a file nobody re-reads. Two
# rules about what goes in them ride along: a re-signed symbol's callers, and an
# order in which every step leaves something that runs.
#
# Exits 0 when both halves hold, 1 otherwise.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
skills="$root/plugins/gku/skills"
[ -d "$skills" ] || { printf 'no skills at %s\n' "$skills" >&2; exit 1; }

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
# Newlines, runs of spaces and the backticks the prose wraps `Modify:` in — the
# phrase is what matters, not how markdown dressed it.
flat() { tr '\n' ' ' < "$1" | tr -d '`' | tr -s ' '; }

# The writers: every skill that produces a task file gives its steps the three
# lines — and each on its own line, indented under the step. One packed line
# would satisfy a search for the three words while giving the readers a second
# shape to parse, which is exactly what happened before this was asserted.
for s in plan research audit; do
  f="$skills/$s/SKILL.md"
  for part in 'Create:' 'Modify:' 'Test:'; do
    grep -qE "^ +- $part" "$f" || note "$s: its Steps template has no indented $part line of its own"
  done
done

# The readers: the lists exist for them.
flat "$skills/implement/SKILL.md" | grep -q 'Modify: paths first' || note 'implement: does not start from the step Modify: paths'
flat "$skills/review/SKILL.md" | grep -q 'Modify: paths' || note 'review: does not narrow the symbol grep to the steps Modify: paths'

# A changed signature: plan puts its callers in the same step's Modify: list, and
# review greps for callers still written for the old one. Without both, the change
# lands in one step and its callers break in another.
plf="$(flat "$skills/plan/SKILL.md")"
printf '%s' "$plf" | grep -q 'lists those callers under Modify:' || note 'plan: a step that changes a signature does not list its callers'
flat "$skills/review/SKILL.md" | grep -q 're-signed' || note 'review: the caller grep skips symbols whose signature changed'

# The order of the steps: each leaves something that runs, so each can be checked.
printf '%s' "$plf" | grep -q 'each one leaves something that runs' || note 'plan: steps may be ordered layer by layer, unchecked until the last'

if [ "$fails" -eq 0 ]; then
  printf 'file-lists: the three planners write them, implement and review read them; callers and order hold\n'
else
  printf 'file-lists: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
