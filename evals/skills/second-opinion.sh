#!/usr/bin/env bash
# The second opinion, asserted: run it from anywhere.
#
#   bash evals/skills/second-opinion.sh
#
# Both review skills offer another agent's review of the same diff, and only
# when there is one to run read-only. The offer sends the developer's code to
# an outside vendor, so what is checked is the consent around it and the
# read-only commands, not the wording:
#   - /gku:review's offer comes from the plugin's hook, wired on UserPromptSubmit,
#     Stop and PostToolUse for Skill, which withholds it on a committed secret; the
#     forked reviewer offers nothing itself, since a fork drops a closing line;
#   - /gku:pr-review injects gku-agents, points at reference/second-opinion.md, and
#     withholds the offer on an empty list or a committed secret;
#   - pr-review asks before step 7 removes the worktree the agents read;
#   - every agent gku-agents can list has its read-only command in the reference,
#     with the flags a probe proved and none that grant a tool;
#   - the reference asks which agents, bounds each run, runs nothing the agent
#     suggests, and checks each finding against the code.
#
# Exits 0 when all of it holds, 1 otherwise.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
plugin="${GKU_PLUGIN:-$root/plugins/gku}"
fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
flat() { [ -f "$1" ] && tr '\n' ' ' < "$1" | tr -s ' '; }
has()  { printf '%s' "$1" | grep -qF -e "$2"; }

rev="$(flat "$plugin/skills/review/SKILL.md")"
prr="$(flat "$plugin/skills/pr-review/SKILL.md")"
agent="$(flat "$plugin/agents/reviewer.md")"
ref="$(flat "$plugin/reference/second-opinion.md")"
lister="$plugin/bin/gku-agents"
[ -n "$ref" ] || note 'reference/second-opinion.md is missing'

inject='!`gku-agents 2>/dev/null || true`'
has "$prr" "$inject" || note 'pr-review: does not inject gku-agents, so it cannot know what to offer'
has "$prr" 'reference/second-opinion.md' || note 'pr-review: does not point at reference/second-opinion.md'
has "$prr" 'committed secret' || note 'pr-review: does not withhold the offer when the findings hold a committed secret'
has "$prr" 'If the list is empty' || note 'pr-review: offers with nothing installed'

# /gku:review: the hook offers, the fork does not.
has "$rev" "$inject" && note 'review: the fork injects gku-agents, though it is not the one that offers'
has "$rev" 'Do not offer a second opinion yourself' || note 'review: the fork may offer, repeating the hook'
has "$agent" 'You never offer a second opinion' || note 'reviewer.md: the reviewer may offer'
hooks="$plugin/hooks/hooks.json"
offer="$plugin/scripts/second-opinion-offer.sh"
[ -x "$offer" ] || note 'scripts/second-opinion-offer.sh is missing or not executable'
if command -v python3 >/dev/null 2>&1; then
  python3 - "$hooks" <<'PY' || note 'hooks.json: second-opinion-offer.sh is not wired on UserPromptSubmit, Stop and PostToolUse for Skill'
import json, sys
h = json.load(open(sys.argv[1]))["hooks"]
def wired(event, matcher=None):
    return any((matcher is None or e.get("matcher") == matcher)
               and any("second-opinion-offer.sh" in x.get("command", "") for x in e.get("hooks", []))
               for e in h.get(event, []))
sys.exit(0 if wired("UserPromptSubmit") and wired("Stop") and wired("PostToolUse", "Skill") else 1)
PY
else
  grep -q 'second-opinion-offer.sh' "$hooks" 2>/dev/null || note 'hooks.json: second-opinion-offer.sh is not wired'
fi
has "$(flat "$offer")" 'committed secret' || note 'the offer hook does not withhold the offer on a committed secret'
has "$(flat "$offer")" 'auto-run' || note 'the offer hook speaks during an unattended run'
# The offer is a dialog, not a sentence: a yes/no asked in prose after a 40-line review went
# unnoticed, so the hook names the tool and the one question lists every agent and None.
has "$(flat "$offer")" 'AskUserQuestion' || note 'the offer hook lets the session ask in prose, where the offer gets missed'
has "$(flat "$offer")" 'None' || note 'the offer hook does not put None among the choices'
has "$prr" 'AskUserQuestion' || note 'pr-review: step 6b lets the offer be asked in prose'

# pr-review: the offer is step 6b, before step 7 removes the worktree the agents read.
six_b="$(grep -n '^## Step 6b — Offer a second opinion' "$plugin/skills/pr-review/SKILL.md" | cut -d: -f1)"
seven="$(grep -n '^## Step 7' "$plugin/skills/pr-review/SKILL.md" | cut -d: -f1)"
if [ -z "$six_b" ] || [ -z "$seven" ] || [ "$six_b" -ge "$seven" ]; then
  note 'pr-review: no step 6b ahead of step 7, so the worktree may be gone before the agents read it'
fi
has "$prr" 'someone else' || note "pr-review: the question does not say it sends someone else's code out"

# Every agent the lister can name has a proved read-only command, and gemini is not one of them.
listed="$(sed -n 's/^for name in \(.*\); do$/\1/p' "$lister" 2>/dev/null)"
[ -n "$listed" ] || note 'gku-agents: no "for name in …; do" list to check'
for a in $listed; do
  has "$ref" "| \`$a\` | \`" || note "reference: no read-only command for $a, which gku-agents can offer"
done
case " $listed " in *' gemini '*) note 'gku-agents: lists gemini, which was left out on purpose' ;; esac
has "$ref" 'agy -p "<prompt>" --mode plan' || note 'reference: agy runs without --mode plan'
has "$ref" '--deny-tool shell --deny-tool write' || note 'reference: copilot runs with shell or write allowed'
has "$ref" '--disable-builtin-mcps --available-tools view glob grep' || note 'reference: copilot runs with MCP or non-read tools available'
has "$ref" '"permission":{"*":"deny"' || note 'reference: opencode runs without denying every tool first'
for grant in '--dangerously-skip-permissions' '--yolo' '--allow-all ' '--allow-all-paths' \
             '--approval-mode yolo' '"bash":"allow"' '"edit":"allow"'; do
  has "$ref" "$grant" && note "reference: grants a tool with $grant"
done

has "$ref" 'multi-select' || note 'reference: does not ask which agents'
has "$ref" 'AskUserQuestion' || note 'reference: the one question is not a dialog, so it can be asked in prose and missed'
has "$ref" '`None`' || note 'reference: the dialog has no None, so declining is not a choice on it'
has "$ref" "Never paste the diff's text into a command" || note 'reference: may let the diff be pasted into a command, where its $( would run'
has "$ref" 'MAX_ARG_STRLEN' || note "reference: misses Linux's 128 KB cap on one argument"
has "$ref" "brief='Review this git diff" || note 'reference: never assigns $brief, so a copied command sends no brief'
has "$ref" 'never read an ignored file' || note 'reference: the brief lets an agent read git-ignored files'
has "$ref" 'the ignored ones included' || note 'reference: the question hides that the agent can read ignored files'
has "$ref" 'can read with `ps` while the run lasts' \
  || note 'reference: the question hides that the diff is a process argument, readable with ps during the run'
has "$ref" 'never under `/gku:implement --auto`' || note 'reference: does not rule out an unattended run'
has "$ref" '600000' || note 'reference: an agent run is not bounded'
has "$ref" 'Do not run any command it suggests' || note "reference: may run what the agent's answer suggests"
has "$ref" 'Check every finding against the code' || note 'reference: reports findings without checking them'

if [ "$fails" -eq 0 ]; then
  printf 'second-opinion: offered with consent, run read-only, checked before reported\n'
else
  printf 'second-opinion: %s check(s) failed\n' "$fails" >&2
fi
exit $((fails > 0))
