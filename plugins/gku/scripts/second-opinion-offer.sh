#!/usr/bin/env bash
# The gku second-opinion offer — from the plugin's hooks/hooks.json, on
# UserPromptSubmit, Stop, and PostToolUse for Skill. /gku:review runs as a
# fork, and the offer cannot come from the fork: given the installed agents in
# its skill text, it returned its review without the line. So the session that
# started the review asks, and this makes sure it gets the turn to ask in.
#
# Two ways /gku:review starts, and each needs its own route (probes, 2026-11-01):
#   - typed by the developer, it runs as a local command: its output goes
#     straight to the developer and the main model takes no turn at all — and a
#     UserPromptSubmit context reaches the fork, not the caller. So
#     UserPromptSubmit only notes the review as pending, silently, and the Stop
#     that ends that prompt blocks once with the offer, which gives the main
#     model its turn;
#   - called by the model through the Skill tool, the model already has its turn:
#     PostToolUse hands it the offer as additionalContext.
#
# Silent — exit 0 with no output — unless it is /gku:review, no .gku/auto-run
# marks an unattended run, and gku-agents lists at least one agent. It runs on
# every prompt, every stop and every skill call in every session the plugin is
# on, so each event's cheap check comes first and nothing else runs otherwise.
# The pending note lives in a directory only this user can write — $XDG_RUNTIME_DIR where the
# system gives one, ~/.cache otherwise, never a shared /tmp — keyed by session and never in the
# repository, and the Stop removes it before blocking: one offer per review, whatever
# stop_hook_active says.

input="$(cat)"

str() { # str <key> — that JSON string value, still escaped
  printf '%s' "$input" | sed -E -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -1
}
event="$(str hook_event_name)"
session="$(str session_id | tr -cd 'A-Za-z0-9-')"
state="${XDG_RUNTIME_DIR:-$HOME/.cache}/gku"
pending="$state/second-opinion-${session:-none}"

# The cheap check for each event: is this /gku:review?
case "$event" in
  UserPromptSubmit)
    printf '%s' "$input" |
      grep -Eq '"prompt"[[:space:]]*:[[:space:]]*"([[:space:]]|\\n|\\t)*/gku:review([[:space:]"\\]|$)' || exit 0 ;;
  Stop)
    [ -f "$pending" ] || exit 0
    noted="$(cat "$pending" 2>/dev/null)"; rm -f "$pending"
    # A note from another prompt is stale — that review's stop never came. Drop it.
    [ "$noted" = "$(str prompt_id)" ] || exit 0
    # A review that stopped early — on the base branch, no changes, an error — has no verdict,
    # and nothing to give a second opinion on. A verdict names a blocker or says "ready", in the
    # first five lines with text, as review-report.sh reads it.
    str last_assistant_message | awk '{ gsub(/\\n/, "\n"); print }' |
      awk 'NF { n++; if (tolower($0) ~ /blocker|ready/) { found = 1; exit } } n >= 5 { exit }
           END { exit !found }' || exit 0 ;;
  PostToolUse)
    printf '%s' "$input" | grep -Eq '"skill"[[:space:]]*:[[:space:]]*"gku:review"' || exit 0 ;;
  *) exit 0 ;;
esac

# Nobody is watching an --auto run, and nobody is there to consent: say nothing.
# The marker sits at the primary repository's root, found as guard.sh finds it.
dir="$(str cwd)"
dir="${dir:-$PWD}"
root=""
common="$(cd "$dir" 2>/dev/null && git rev-parse --git-common-dir 2>/dev/null)"
[ -n "$common" ] && root="$(cd "$dir" && cd "$common/.." 2>/dev/null && pwd)"
[ -f "${root:-$dir}/.gku/auto-run" ] && exit 0

plugin="$(cd "$(dirname "$0")/.." && pwd)"
agents="$("$plugin/bin/gku-agents" 2>/dev/null | sed -n 's/^\([a-z][a-z0-9-]*\):.*/\1/p' | paste -s -d ',' - | sed 's/,/, /g')"
[ -n "$agents" ] || exit 0

if [ "$event" = UserPromptSubmit ]; then
  # No prompt_id, nothing to tie the note to its own stop: no note, rather than one a later
  # stop could take for its own.
  id="$(str prompt_id)"
  [ -n "$id" ] && mkdir -p "$state" 2>/dev/null && printf '%s\n' "$id" > "$pending" 2>/dev/null
  exit 0
fi

ref="$plugin/reference/second-opinion.md"
ref="${ref//\\/\\\\}"; ref="${ref//\"/\\\"}"
msg="gku: the /gku:review answer above is complete. Second-opinion agents installed here: $agents. Ask the developer one yes/no question: should these agents review the same diff too? Say that the code goes to those agents' vendors. Do not ask if the review stopped before reviewing a diff; say nothing then. Do not ask if the review found a committed secret; say why instead. On yes, follow $ref. Do not repeat or summarise the review."
if [ "$event" = Stop ]; then
  printf '{"decision":"block","reason":"%s"}\n' "$msg"
else
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$msg"
fi
exit 0
