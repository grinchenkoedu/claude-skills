#!/usr/bin/env bash
# Frontmatter invariants for the gku skills — run them from anywhere:
#
#   bash evals/skills/frontmatter.sh
#
# The rules these assert are the ones a reader of a skill's description is
# entitled to rely on: a skill that writes is never fired by the model on its
# own, and a skill that promises to read never edits a file that was already
# there. Nothing here declares when_to_use: every gku skill is a command the
# developer types.
#
# Exits 0 when every skill matches, 1 otherwise, naming each mismatch.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
skills="$root/plugins/gku/skills"
# A run that finds nothing to check must fail, not pass: a moved directory
# would otherwise leave this green while it asserted nothing at all.
[ -d "$skills" ] || { printf 'no skills at %s\n' "$skills" >&2; exit 1; }
count="$(ls -d "$skills"/*/ 2>/dev/null | wc -l | tr -d ' ')"
[ "$count" -gt 0 ] || { printf 'no skills under %s\n' "$skills" >&2; exit 1; }

WRITES="init implement fix pr pr-resolve audit"          # never model-invoked
READS="plan research review verify pr-review audit"      # never edit an existing file
HOOKED="implement fix pr pr-resolve"                     # register the guard

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
head_of() { sed -n '2,/^---$/p' "$skills/$1/SKILL.md"; }   # the frontmatter, minus its opening ---
has() { head_of "$1" | grep -q "^$2"; }
in_list() { case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

for dir in "$skills"/*/; do
  s="$(basename "$dir")"
  [ -f "$dir/SKILL.md" ] || continue

  has "$s" 'user-invocable: true' || note "$s: not user-invocable"
  has "$s" 'when_to_use'          && note "$s: declares when_to_use; gku skills are typed, not fired"

  if in_list "$s" "$WRITES"; then
    has "$s" 'disable-model-invocation: true' || note "$s: writes, so it must carry disable-model-invocation: true"
  else
    has "$s" 'disable-model-invocation' && note "$s: does not write; it should stay model-invocable"
  fi

  if in_list "$s" "$READS"; then
    has "$s" 'disallowed-tools: Edit, NotebookEdit' || note "$s: promises not to edit, so it must carry disallowed-tools: Edit, NotebookEdit"
    head_of "$s" | grep -q '^disallowed-tools:.*Write' && note "$s: must keep Write — it writes a task file or a report"
  fi

  if in_list "$s" "$HOOKED"; then
    has "$s" 'hooks:' || note "$s: pushes or commits, so it must register the guard hook"
    head_of "$s" | grep -q 'scripts/guard.sh' || note "$s: hook does not point at scripts/guard.sh"
  else
    has "$s" 'hooks:' && note "$s: registers a hook but neither pushes nor commits"
  fi
done

if [ "$fails" -eq 0 ]; then
  printf 'skills: frontmatter invariants hold across %s skills\n' "$count"
else
  printf 'skills: %s frontmatter problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
