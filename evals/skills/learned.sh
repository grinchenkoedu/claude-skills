#!/usr/bin/env bash
# The learned-notes file, asserted: run it from anywhere.
#
#   bash evals/skills/learned.sh
#
# .gku/learned.md is the only file a later run reads back on its own, so it has
# two properties worth holding: something writes to it, something reads it, and
# the writers cap it — /gku:plan and /gku:research pay for its length on every
# run, and an uncapped file grows without anybody deciding to spend that.
#
# Exits 0 when they hold, 1 otherwise.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
skills="$root/plugins/gku/skills"
reports="$root/plugins/gku/reference/reports.md"
[ -d "$skills" ] && [ -f "$reports" ] || { printf 'no skills or reports.md under %s\n' "$root" >&2; exit 1; }

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }

grep -q 'learned.md' "$reports" || note 'reports.md: the learned-notes file is undocumented'
flat "$reports" | grep -q 'last 20 lines' || note 'reports.md: the cap on the file is gone — plan and research pay for its length every run'
# The words are not the cap; the command is. Assert the mechanism too, and the
# mkdir without which the first note in a repository is lost.
grep -q 'tail -20' "$reports" || note 'reports.md: the cap has no command behind it'
grep -q 'mkdir -p "$root/.gku"' "$reports" || note 'reports.md: the append can land in a directory that does not exist'

for s in implement fix; do
  f="$skills/$s/SKILL.md"
  grep -q 'learned.md' "$f" || note "$s: ends a run without offering the next one what it found out"
  flat "$f" | grep -q 'prune to the last 20 lines' || note "$s: appends without pruning"
done

for s in plan research; do
  f="$skills/$s/SKILL.md"
  grep -q 'cat .gku/learned.md' "$f" || note "$s: never reads the notes, so writing them buys nothing"
done

if [ "$fails" -eq 0 ]; then
  printf 'learned: implement and fix append and prune, plan and research read\n'
else
  printf 'learned: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
