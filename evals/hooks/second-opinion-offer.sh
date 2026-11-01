#!/usr/bin/env bash
# Behaviour cases for plugins/gku/scripts/second-opinion-offer.sh — run them from anywhere:
#
#   bash evals/hooks/second-opinion-offer.sh
#
# The hook tells the session that started /gku:review which agents could give a
# second opinion. Every case is "loud or silent | event | prompt or skill | agents
# installed | whether .gku/auto-run exists". Loud means its output is valid JSON
# whose additionalContext names each installed agent and the reference's absolute
# path, under the right hookEventName. The script runs from a temporary copy of
# the plugin's layout, so the stub gku-agents beside it decides what is installed.
#
# Exits 0 when every case matches, 1 otherwise, naming each mismatch.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
hook="${SECOND_OPINION_HOOK:-$root/plugins/gku/scripts/second-opinion-offer.sh}"
[ -x "$hook" ] || { printf 'no executable hook at %s\n' "$hook" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM
# A plugin directory with a space in it: the reference path must survive one.
plug="$work/a plugin"; mkdir -p "$plug/scripts" "$plug/bin" "$plug/reference"
cp "$hook" "$plug/scripts/second-opinion-offer.sh"
: > "$plug/reference/second-opinion.md"

fails=0
run() { # run <want> <event> <subject> <agents, comma-separated> <marker>
  local want="$1" event="$2" subject="$3" agents="$4" marker="$5" dir out payload a got=silent
  dir="$work/cwd"; rm -rf "$dir"; mkdir -p "$dir"
  ( cd "$dir" && git init -q . )
  [ "$marker" = yes ] && mkdir -p "$dir/.gku" && printf 'started\n' > "$dir/.gku/auto-run"
  { printf '#!/bin/sh\n'; for a in ${agents//,/ }; do printf 'echo "%s: /x/%s"\n' "$a" "$a"; done; } \
    > "$plug/bin/gku-agents"
  chmod +x "$plug/bin/gku-agents"
  if [ "$event" = UserPromptSubmit ]; then
    payload="$(printf '{"cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "$dir" "$subject")"
  else
    payload="$(printf '{"cwd":"%s","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"%s"},"tool_response":"x"}' "$dir" "$subject")"
  fi
  out="$(printf '%s' "$payload" | "$plug/scripts/second-opinion-offer.sh" 2>/dev/null)"
  if [ -n "$out" ]; then
    got=loud
    printf '%s' "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null || got=invalid-json
    case "$out" in *"\"hookEventName\":\"$event\""*) ;; *) got=wrong-event ;; esac
    case "$out" in *"$plug/reference/second-opinion.md"*) ;; *) got=no-reference ;; esac
    for a in ${agents//,/ }; do case "$out" in *"$a"*) ;; *) got="missing-$a" ;; esac; done
  fi
  if [ "$got" != "$want" ]; then
    printf 'FAIL  want=%s got=%s  event=%s subject=%s agents=%s marker=%s\n' \
      "$want" "$got" "$event" "$subject" "${agents:-none}" "$marker"
    fails=$((fails + 1))
  fi
}

while IFS='|' read -r want event subject agents marker; do
  case "$want" in ''|'#'*) continue ;; esac
  run "$want" "$event" "$subject" "$agents" "$marker"
done <<'TABLE'
# loud — /gku:review started, an agent installed, somebody watching
loud|UserPromptSubmit|/gku:review|agy|no
loud|UserPromptSubmit|/gku:review --deep|agy,copilot,opencode|no
loud|UserPromptSubmit|  /gku:review|copilot|no
loud|PostToolUse|gku:review|opencode|no
# silent — another prompt or skill, even one that names the review
silent|UserPromptSubmit|/gku:pr-review 12|agy|no
silent|UserPromptSubmit|/gku:reviewer|agy|no
silent|UserPromptSubmit|please run /gku:review later|agy|no
silent|UserPromptSubmit|hello|agy|no
silent|PostToolUse|gku:pr-review|agy|no
silent|PostToolUse|gku:fix|agy|no
# silent — nothing installed
silent|UserPromptSubmit|/gku:review||no
silent|PostToolUse|gku:review||no
# silent — an unattended run
silent|UserPromptSubmit|/gku:review|agy|yes
silent|PostToolUse|gku:review|agy|yes
TABLE

if [ "$fails" -eq 0 ]; then
  printf 'second-opinion-offer: all cases pass\n'
else
  printf 'second-opinion-offer: %s case(s) failed\n' "$fails" >&2
fi
exit $((fails > 0))
