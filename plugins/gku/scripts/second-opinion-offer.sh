#!/usr/bin/env bash
# The gku second-opinion offer — UserPromptSubmit and PostToolUse (Skill), from
# the plugin's hooks/hooks.json. /gku:review runs as a fork, and a fork reliably
# drops a closing line nobody checks: given the installed agents in its skill
# text, it returned its review without the offer. The session that called it
# does get a turn once the fork returns, and a hook's additionalContext reaches
# that session — so this tells the caller what to ask, not the fork.
#
# Two ways /gku:review starts, one event each, never both for one review:
#   - typed by the developer → UserPromptSubmit, the prompt starting /gku:review
#     (a typed command never goes through the Skill tool);
#   - called by the model → PostToolUse on Skill, with "skill":"gku:review".
#
# Silent — exit 0 with no output — unless that holds, no .gku/auto-run marks an
# unattended run, and gku-agents lists at least one agent. Then it prints the
# additionalContext: the agents, and what the caller asks the developer. It runs
# on every prompt in every session the plugin is on, so the prompt is the first
# thing checked and nothing else runs for any other.

input="$(cat)"

# Which event, and is it /gku:review? Matched on the raw JSON: the prompt and the
# skill name are plain strings, and nothing here needs decoding beyond them.
event=""
case "$input" in
  *'"hook_event_name":"UserPromptSubmit"'*|*'"hook_event_name": "UserPromptSubmit"'*)
    printf '%s' "$input" |
      grep -Eq '"prompt"[[:space:]]*:[[:space:]]*"([[:space:]]|\\n|\\t)*/gku:review([[:space:]"\\]|$)' &&
      event=UserPromptSubmit ;;
  *'"hook_event_name":"PostToolUse"'*|*'"hook_event_name": "PostToolUse"'*)
    printf '%s' "$input" | grep -Eq '"skill"[[:space:]]*:[[:space:]]*"gku:review"' &&
      event=PostToolUse ;;
esac
[ -n "$event" ] || exit 0

# Nobody is watching an --auto run, and nobody is there to consent: say nothing.
# The marker sits at the primary repository's root, found as guard.sh finds it.
dir="$(printf '%s' "$input" | sed -E -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -1)"
dir="${dir:-$PWD}"
root=""
common="$(cd "$dir" 2>/dev/null && git rev-parse --git-common-dir 2>/dev/null)"
[ -n "$common" ] && root="$(cd "$dir" && cd "$common/.." 2>/dev/null && pwd)"
[ -f "${root:-$dir}/.gku/auto-run" ] && exit 0

plugin="$(cd "$(dirname "$0")/.." && pwd)"
agents="$("$plugin/bin/gku-agents" 2>/dev/null | sed -n 's/^\([a-z][a-z0-9-]*\):.*/\1/p' | paste -sd ',' - | sed 's/,/, /g')"
[ -n "$agents" ] || exit 0

ref="$plugin/reference/second-opinion.md"
ref="${ref//\\/\\\\}"; ref="${ref//\"/\\\"}"
msg="gku: second-opinion agents installed here: $agents. When the /gku:review answer is back, show it as it is, then ask the developer one yes/no question: should these agents review the same diff too? Say that the code goes to those agents' vendors. Do not ask if the review found a committed secret; say why instead. On yes, follow $ref."
printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$event" "$msg"
exit 0
