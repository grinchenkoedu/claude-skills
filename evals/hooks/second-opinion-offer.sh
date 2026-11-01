#!/usr/bin/env bash
# Behaviour cases for plugins/gku/scripts/second-opinion-offer.sh — run them from anywhere:
#
#   bash evals/hooks/second-opinion-offer.sh
#
# The hook makes the session that started /gku:review ask about a second
# opinion. A typed review notes itself on UserPromptSubmit, silently, and the
# Stop that ends that prompt blocks once with the offer; a review the model
# calls gets the offer on PostToolUse. Each case is a sequence of events in one
# session, and what each must print: "silent", "block" (a Stop decision naming
# every installed agent and the reference's absolute path) or "context" (a
# PostToolUse additionalContext saying the same). The script runs from a copy of
# the plugin's layout, with a stub gku-agents beside it and its own XDG_RUNTIME_DIR.
#
# Exits 0 when every case matches, 1 otherwise, naming each mismatch.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
hook="${SECOND_OPINION_HOOK:-$root/plugins/gku/scripts/second-opinion-offer.sh}"
[ -x "$hook" ] || { printf 'no executable hook at %s\n' "$hook" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM
# A plugin directory with a space in it: the reference path must survive one.
plug="$work/a plugin"; mkdir -p "$plug/scripts" "$plug/bin" "$plug/reference" "$work/tmp"
cp "$hook" "$plug/scripts/second-opinion-offer.sh"
: > "$plug/reference/second-opinion.md"

fails=0 label="" agents="" dir=""
setup() { # setup <label> <agents, comma-separated> <auto-run marker yes|no>
  label="$1" agents="$2"
  dir="$work/cwd"; rm -rf "$dir" "$work/tmp"; mkdir -p "$dir" "$work/tmp"
  ( cd "$dir" && git init -q . )
  [ "$3" = yes ] && mkdir -p "$dir/.gku" && printf 'started\n' > "$dir/.gku/auto-run"
  { printf '#!/bin/sh\n'; for a in ${agents//,/ }; do printf 'echo "%s: /x/%s"\n' "$a" "$a"; done; } \
    > "$plug/bin/gku-agents"
  chmod +x "$plug/bin/gku-agents"
}
send() { # send <want silent|block|context> <event> [prompt or skill] [prompt_id] [stop's message]
  local want="$1" ev="$2" subject="${3-}" pid="${4-p1}" said="${5-**2 blockers first**}" payload out got=silent a idf
  idf="\"prompt_id\":\"$pid\","; [ "$pid" = - ] && idf=""   # "-": a payload with no prompt_id
  case "$ev" in
    UserPromptSubmit) payload="{\"session_id\":\"s-1\",$idf\"cwd\":\"$dir\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":\"$subject\"}" ;;
    Stop)             payload="{\"session_id\":\"s-1\",$idf\"cwd\":\"$dir\",\"hook_event_name\":\"Stop\",\"stop_hook_active\":false,\"last_assistant_message\":\"$said\"}" ;;
    PostToolUse)      payload="{\"session_id\":\"s-1\",$idf\"cwd\":\"$dir\",\"hook_event_name\":\"PostToolUse\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"$subject\"},\"tool_response\":\"x\"}" ;;
  esac
  out="$(printf '%s' "$payload" | XDG_RUNTIME_DIR="$work/tmp" "$plug/scripts/second-opinion-offer.sh" 2>/dev/null)"
  if [ -n "$out" ]; then
    case "$out" in
      *'"decision":"block"'*) got=block ;;
      *'"hookEventName":"PostToolUse"'*) got=context ;;
      *) got=unknown-output ;;
    esac
    printf '%s' "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null || got=invalid-json
    case "$out" in *"$plug/reference/second-opinion.md"*) ;; *) got="$got-no-reference" ;; esac
    for a in ${agents//,/ }; do case "$out" in *"$a"*) ;; *) got="$got-missing-$a" ;; esac; done
  fi
  if [ "$got" != "$want" ]; then
    printf 'FAIL  %-28s %-16s %-22s want=%s got=%s\n' "$label" "$ev" "${subject:--}" "$want" "$got"
    fails=$((fails + 1))
  fi
}

# A typed review: silent on the prompt, one block on its stop, nothing on the next.
setup typed agy,copilot,opencode no
send silent UserPromptSubmit '/gku:review'
# …and its note is in this user's own directory, not a shared /tmp.
ls "$work/tmp/gku/second-opinion-s-1" >/dev/null 2>&1 ||
  { printf 'FAIL  typed: no note under XDG_RUNTIME_DIR/gku\n'; fails=$((fails + 1)); }
send block  Stop
send silent Stop

setup typed-with-args agy no
send silent UserPromptSubmit '/gku:review --deep'
send block  Stop

setup typed-leading-space copilot no
send silent UserPromptSubmit '  /gku:review'
send block  Stop

# A review with a verdict below a heading still gets it; one that stopped early does not.
setup heading-then-verdict agy no
send silent UserPromptSubmit '/gku:review'
send block  Stop '' p1 '# Review\n\n**Ready to push**'
for early in 'You are on `main` — switch to your branch first.' 'No changes against `main`.'; do
  setup "early-stop" agy no
  send silent UserPromptSubmit '/gku:review'
  send silent Stop '' p1 "$early"
done

# A review in another language keeps the English label on its verdict line (reference/language.md
# rule 4): that word is what the hook reads. Without it the offer never comes — the miss the rule
# exists for, kept here as a case so the gap stays visible.
for said in '**2 BLOCKERS** — спочатку виправити' '**Ready** — можна пушити, 2 попередження варто глянути'; do
  setup "labelled-uk-verdict" copilot no
  send silent UserPromptSubmit '/gku:review'
  send block  Stop '' p1 "$said"
done
setup unlabelled-uk-verdict copilot no
send silent UserPromptSubmit '/gku:review'
send silent Stop '' p1 '**2 блокери спочатку**'

# The model calls it: the offer arrives as context, and no stop blocks after it.
setup model-called opencode no
send context PostToolUse 'gku:review'
send silent  Stop

# Not a review: nothing, then, and nothing at its stop.
setup other-prompts agy no
for p in '/gku:pr-review 12' '/gku:reviewer' 'please run /gku:review later' 'hello'; do
  send silent UserPromptSubmit "$p"
  send silent Stop
done
setup other-skills agy no
send silent PostToolUse 'gku:pr-review'
send silent PostToolUse 'gku:fix'

# A stop with no review before it, and a note left by an earlier prompt.
setup plain-stop agy no
send silent Stop
setup stale-note agy no
send silent UserPromptSubmit '/gku:review' p1
send silent Stop '' p2
send silent Stop '' p1

# No prompt_id to tie the note to its stop: no note, so no offer, rather than one that may be stale.
setup no-prompt-id agy no
send silent UserPromptSubmit '/gku:review' -
send silent Stop '' -

# Nothing installed, or nobody watching: no offer by either route.
setup no-agents '' no
send silent UserPromptSubmit '/gku:review'
send silent Stop
send silent PostToolUse 'gku:review'
setup unattended agy yes
send silent UserPromptSubmit '/gku:review'
send silent Stop
send silent PostToolUse 'gku:review'

if [ "$fails" -eq 0 ]; then
  printf 'second-opinion-offer: all cases pass\n'
else
  printf 'second-opinion-offer: %s case(s) failed\n' "$fails" >&2
fi
exit $((fails > 0))
