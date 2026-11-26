#!/usr/bin/env bash
# Every command gku-hud's pane can put in the prompt is one the skill still takes:
# run it from anywhere.
#
#   bash evals/hud/commands.sh
#
# plugins/gku-hud/src/actions.ts spells the commands its buttons fill —
# `/gku:implement <task> --continue`, `/gku:fix <report>` and the rest. They are
# written for the person to send, so a flag a skill renames or drops would sit in
# the prompt box looking right and do something else. This reads each command
# line out of actions.ts and holds it to that skill's own `## Arguments` section:
# the skill exists, each flag the command passes is named there, and a command
# that passes a file goes to a skill whose Arguments take one.
#
# Exits 0 when every command holds, 1 otherwise, naming each mismatch.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
actions="$root/plugins/gku-hud/src/actions.ts"
skills="$root/plugins/gku/skills"
[ -f "$actions" ] || { printf 'no actions.ts at %s\n' "$actions" >&2; exit 1; }

fails=0
checked=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
# The body of one ## section: from its heading to the next heading or the end.
section() { awk -v h="## $2" '$0 == h {p=1; next} /^## /{p=0} p' "$1"; }

# Each `command: '...'` or `command: \`...\`` in actions.ts, as the text between the quotes.
commands="$(grep -oE "command: ['\`][^'\`]*['\`]" "$actions" | sed -E "s/^command: ['\`]//; s/['\`]$//")"
[ -n "$commands" ] || note 'actions.ts holds no command: the check would be vacuous'

while IFS= read -r command; do
  [ -n "$command" ] || continue
  checked=$((checked + 1))
  skill="$(printf '%s' "$command" | sed -nE 's|^/gku:([a-z-]+).*|\1|p')"
  if [ -z "$skill" ]; then
    note "'$command' does not start with a /gku: skill"
    continue
  fi
  file="$skills/$skill/SKILL.md"
  [ -f "$file" ] || { note "'$command': no skill $skill at plugins/gku/skills/$skill/SKILL.md"; continue; }
  args="$(section "$file" 'Arguments')"
  [ -n "$args" ] || { note "'$command': $skill has no ## Arguments section"; continue; }

  for flag in $(printf '%s' "$command" | grep -oE -- '--[a-z][a-z-]*'); do
    printf '%s' "$args" | grep -qF -e "\`$flag" || note "'$command': $skill's Arguments do not name $flag"
  done
  case "$command" in
    *'${path}'*)
      printf '%s' "$args" | grep -qi 'file' || note "'$command': $skill's Arguments take no file" ;;
  esac
done <<EOF_COMMANDS
$commands
EOF_COMMANDS

[ "$checked" -ge 5 ] || note "only $checked commands read from actions.ts: the extraction has stopped matching"

if [ "$fails" -eq 0 ]; then
  printf 'hud-commands: all %s commands gku-hud can fill name a skill, flags and file argument the skill takes\n' "$checked"
else
  printf 'hud-commands: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
