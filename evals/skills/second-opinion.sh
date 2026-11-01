#!/usr/bin/env bash
# The second opinion, asserted: run it from anywhere.
#
#   bash evals/skills/second-opinion.sh
#
# Both review skills offer another agent's review of the same diff, and only
# when there is one to run read-only. The offer sends the developer's code to
# an outside vendor, so what is checked is the consent around it and the
# read-only commands, not the wording:
#   - /gku:review and /gku:pr-review inject gku-agents and point at
#     reference/second-opinion.md; neither offers on an empty list or a committed
#     secret, the review never offers when dispatched, and the offer sits above the
#     report path the review-report hook expects last;
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
for s in review pr-review; do
  body="$rev"; [ "$s" = pr-review ] && body="$prr"
  has "$body" "$inject" || note "$s: does not inject gku-agents, so it cannot know what to offer"
  has "$body" 'reference/second-opinion.md' || note "$s: does not point at reference/second-opinion.md"
  has "$body" 'committed secret' || note "$s: does not withhold the offer when the findings hold a committed secret"
done
has "$rev" 'list above is empty' || note 'review: offers with nothing installed'
has "$rev" 'you were dispatched' || note 'review: a dispatched review may offer, with nobody to say yes'
has "$rev" 'above the report path' || note 'review: the offer may land below the report path the hook expects last'
has "$rev" 'absolute path' || note 'review: the offer may name a relative path the main session cannot resolve'
has "$agent" 'Dispatched, you offer no second opinion' || note 'reviewer.md: a dispatched reviewer may offer'

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
has "$ref" '"permission":{"*":"deny"' || note 'reference: opencode runs without denying every tool first'
for grant in '--dangerously-skip-permissions' '--yolo' '--allow-all ' '--allow-all-paths' \
             '--approval-mode yolo' '"bash":"allow"' '"edit":"allow"'; do
  has "$ref" "$grant" && note "reference: grants a tool with $grant"
done

has "$ref" 'multi-select' || note 'reference: does not ask which agents'
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
