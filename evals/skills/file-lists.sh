#!/usr/bin/env bash
# The per-step file lists, asserted: run it from anywhere.
#
#   bash evals/skills/file-lists.sh
#
# Three skills write plans and two read them. The lists are only worth writing
# because something reads them: /gku:implement opens the Modify: paths instead of
# searching the repository, and /gku:review greps them for symbols that moved. If
# either half goes, the lists become decoration in a file nobody re-reads.
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

# The writers: every skill that produces a task file gives its steps the three lines.
for s in plan research audit; do
  f="$skills/$s/SKILL.md"
  for part in 'Create:' 'Modify:' 'Test:'; do
    grep -q "$part" "$f" || note "$s: its Steps template has no $part line"
  done
done

# The readers: the lists exist for them.
flat "$skills/implement/SKILL.md" | grep -q 'Modify: paths first' || note 'implement: does not start from the step Modify: paths'
flat "$skills/review/SKILL.md" | grep -q 'Modify: paths' || note 'review: does not narrow the symbol grep to the steps Modify: paths'

if [ "$fails" -eq 0 ]; then
  printf 'file-lists: the three planners write them, implement and review read them\n'
else
  printf 'file-lists: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
