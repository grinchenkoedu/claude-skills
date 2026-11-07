#!/usr/bin/env bash
# Effort pins live on the agents, never in a skill's frontmatter:
#
#   bash evals/agents/effort.sh
#
# A stronger model at low effort usually spends fewer tokens than a weaker one
# at high effort, and Claude Code reads an `effort:` line from an agent or a
# skill file. An agent starts its own conversation, so its pin costs nothing;
# the two mechanical agents on Haiku run at low effort. A skill runs inside the
# session's conversation, and a changed effort invalidates its cached messages
# on the way in and again on the way back — so no SKILL.md carries the key, and
# the session's own setting is what a skill runs at. The reviewer's pin is
# decided by measurement (evals/live/README.md) and is not asserted here.
#
# Exits 0 when both hold, 1 otherwise.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
plugin="${GKU_PLUGIN_DIR:-$root/plugins/gku}"

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }

for agent in runner scout; do
  f="$plugin/agents/$agent.md"
  [ -f "$f" ] || { note "agents/$agent.md: missing"; continue; }
  awk 'NR==1{next} /^---/{exit} {print}' "$f" | grep -qx 'effort: low' \
    || note "agents/$agent.md: no 'effort: low' in its frontmatter"
done

for f in "$plugin"/skills/*/SKILL.md; do
  s="$(basename "$(dirname "$f")")"
  awk 'NR==1{next} /^---/{exit} {print}' "$f" | grep -qE '^effort:' \
    && note "$s: carries an effort: key — a skill runs in the session's cache, pin effort on an agent instead"
done

if [ "$fails" -eq 0 ]; then
  printf 'effort: runner and scout pinned low; no skill overrides the session\n'
else
  printf 'effort: %s gap(s)\n' "$fails" >&2
fi
exit $((fails > 0))
