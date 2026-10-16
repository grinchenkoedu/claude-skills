#!/usr/bin/env bash
# The per-step file lists, asserted: run it from anywhere.
#
#   bash evals/skills/file-lists.sh
#
# Three skills write plans and two read them. The lists are only worth writing
# because something reads them: /gku:implement opens the Modify: paths instead of
# searching the repository, and /gku:review greps them for symbols that moved. If
# either half goes, the lists become decoration in a file nobody re-reads. One
# rule about what goes in them rides along: the callers of a changed signature.
#
# Exits 0 when all of it holds, 1 otherwise.

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
revf="$(flat "$skills/review/SKILL.md")"
printf '%s' "$revf" | grep -q 'symbols and those with a changed signature' ||
  note 'review: the caller grep skips symbols whose signature changed'
printf '%s' "$revf" | grep -q 'every call site. It returns the list; you judge it' ||
  note 'review: the --deep sub-agent decides which callers break, or skips changed signatures'
printf '%s' "$revf" | grep -q 'grep the whole tree' ||
  note 'review: a changed signature is grepped in Modify: paths only, where the plan already fixed the callers'

if [ "$fails" -eq 0 ]; then
  printf 'file-lists: the three planners write them, implement and review read them; callers of a changed signature included\n'
else
  printf 'file-lists: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
