#!/usr/bin/env bash
# The guard's list, written once: run it from anywhere.
#
#   bash evals/reference/guard-pointer.sh
#
# scripts/guard.sh refuses a handful of git and gh commands inside the four skills
# that write. That list used to be spelled out in each of their Rules sections and
# in the script's own header, so a change to the guard meant five edits or a quiet
# drift between them. reference/exec.md, read at step 1 of every skill that runs a
# command, now carries it once, and the four Rules sections point there. What is
# checked: the section exists and stays short, it names each refusal, the script
# still refuses each one, and each of the four skills points at the section rather
# than restating the flags.
#
# Exits 0 when all of that holds, 1 otherwise, naming each mismatch.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
exec_md="$root/plugins/gku/reference/exec.md"
guard="$root/plugins/gku/scripts/guard.sh"
skills="$root/plugins/gku/skills"
[ -f "$exec_md" ] || { printf 'no exec.md at %s\n' "$exec_md" >&2; exit 1; }
[ -f "$guard" ]   || { printf 'no guard at %s\n' "$guard" >&2; exit 1; }

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
# Prose wrapped at the file's width: match against a flattened copy, as claims.sh does.
flat() { tr '\n' ' ' | tr -s ' '; }
# The body of one ## section: from its heading to the next heading or the end.
section() { awk -v h="## $2" '$0 == h {p=1; next} /^## /{p=0} p' "$1"; }

# The section itself. Short on purpose: every command-running skill reads this file first,
# and the read-only ones pay for these lines on runs that never touch git.
sec="$(section "$exec_md" 'The guard')"
if [ -z "$sec" ]; then
  note 'exec.md has no "## The guard" section'
else
  prose="$(printf '%s\n' "$sec" | grep -c -v '^[[:space:]]*$')"
  [ "$prose" -le 5 ] || note "exec.md: the guard section is $prose lines of prose; three were asked for, five is the cap"
  secf="$(printf '%s' "$sec" | flat)"
  for want in 'forced push' '--amend' '--no-verify' 'base branch' 'approv' 'auto-run'; do
    printf '%s' "$secf" | grep -qF -e "$want" || note "exec.md: the guard section does not name '$want'"
  done
  printf '%s' "$secf" | grep -qi 'fix' || note 'exec.md: the guard section does not say a refusal is fixed in the code'
fi

# The script refuses what the section says it does, and its header sends a reader to the
# section rather than to the Rules. The refusal texts are what a developer sees.
for want in 'a forced push' '--amend' '--no-verify' 'approving' 'a push to the base branch'; do
  grep -qF -e "refuse \"$want" "$guard" || note "guard.sh: no refusal for '$want', which exec.md promises"
done
sed -n '1,30p' "$guard" | grep -q 'reference/exec.md' || note 'guard.sh: the header does not name reference/exec.md as where the list is written'

# The four Rules sections point at the section and no longer restate the flags.
for s in implement fix pr pr-resolve; do
  f="$skills/$s/SKILL.md"
  [ -f "$f" ] || { note "$s: no SKILL.md"; continue; }
  # A pointer into a file the skill never opens is a dead reference: somewhere before its
  # Rules, the skill has to read exec.md (the 200 characters allow for a parenthesis between).
  awk '/^## Rules/{exit} {print}' "$f" | flat | grep -Eq 'Read.{0,200}`reference/exec\.md`' ||
    note "$s: never reads reference/exec.md, so its Rules point at a list the run never loads"
  rules="$(awk '/^## Rules/{p=1; next} /^## Edge cases/{p=0} p' "$f" | flat)"
  [ -n "$rules" ] || { note "$s: no Rules section before Edge cases"; continue; }
  { printf '%s' "$rules" | grep -q 'the guard' && printf '%s' "$rules" | grep -q 'reference/exec.md'; } ||
    note "$s: the Rules do not point at the guard section in reference/exec.md"
  printf '%s' "$rules" | grep -Eq 'Never `--(no-verify|force|amend)`' &&
    note "$s: the Rules still spell out the flags the guard refuses"
done

if [ "$fails" -eq 0 ]; then
  printf 'guard-pointer: exec.md lists what the guard refuses, the script does, and the four write skills point there\n'
else
  printf 'guard-pointer: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
