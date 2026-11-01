#!/usr/bin/env bash
# The plugin's own agents, asserted: run it from anywhere.
#
#   bash evals/skills/agents.sh
#
# The skills use three sub-agents and no others: gku:reviewer does every review
# in a context that never saw the change being written, gku:runner keeps a long
# test run's output out of the building session, and gku:scout sweeps behind
# --deep. Each is cheap only because its file pins the model, and each is safe
# only because its own prompt forbids what the guard refuses — a skill's hook
# does not see a sub-agent's commands. This checks the files, and that every
# skill that dispatches one names it rather than a general-purpose agent.
#
# Exits 0 when all of it holds, 1 otherwise.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
agents="$root/plugins/gku/agents"
skills="$root/plugins/gku/skills"
[ -d "$skills" ] || { printf 'no skills at %s\n' "$skills" >&2; exit 1; }

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }
head_of() { sed -n '2,/^---$/p' "$1"; }   # the frontmatter, minus its opening ---
field() { head_of "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1; }

# The agents: each exists, pins its model, and carries the guard's rules itself.
for spec in reviewer:sonnet scout:haiku runner:haiku; do
  a="${spec%%:*}" model="${spec#*:}" f="$agents/${spec%%:*}.md"
  [ -f "$f" ] || { note "$a: no agent file at plugins/gku/agents/$a.md"; continue; }
  [ "$(field "$f" name)" = "$a" ] || note "$a: frontmatter name is not '$a', so gku:$a resolves to nothing"
  [ "$(field "$f" model)" = "$model" ] || note "$a: model is not pinned to $model"
  tools="$(field "$f" tools)"
  case ", $tools," in *", Edit,"*|*", NotebookEdit,"*) note "$a: may edit files" ;; esac
  flat "$f" | grep -q 'watches the main session only' ||
    note "$a: does not say the guard cannot see it, so nothing forbids it a forced push or a merge"
done
case ", $(field "$agents/scout.md" tools)," in *", Write,"*) note 'scout: may write files' ;; esac
case ", $(field "$agents/runner.md" tools)," in *", Write,"*) note 'runner: may write files' ;; esac
grep -q '^disallowedTools:.*Edit' "$agents/reviewer.md" 2>/dev/null ||
  note 'reviewer: Edit is not disallowed, so a review could change the code it judges'

# /gku:review forks onto the reviewer, and waits for it.
rev="$skills/review/SKILL.md"
[ "$(field "$rev" context)" = fork ] || note 'review: does not run in a fresh context (context: fork)'
[ "$(field "$rev" agent)" = gku:reviewer ] || note 'review: forks onto something other than gku:reviewer'
[ "$(field "$rev" background)" = false ] || note 'review: forks in the background, so its answer arrives after the turn'
# The fork returns the review as its answer and still writes the report on a blocker: a line
# telling it "not in a file" is what made it skip the report once.
revf="$(flat "$rev")"
printf '%s' "$revf" | grep -qF 'with `--report`, or when there is at least one blocker' ||
  note 'review: no longer writes a report on a blocker'
printf '%s' "$revf" | grep -qF 'not in a file' &&
  note 'review: says "not in a file", which a forked reviewer reads as no report on a blocker'

# The skills that review without being /gku:review dispatch the same agent, with
# facts only — a brief that says what to expect is the bias the fork avoids.
autof="$(flat "$skills/implement/auto.md")"
printf '%s' "$autof" | grep -q 'dispatch `gku:reviewer`' || note 'implement: --auto reviews in the context that wrote the change'
printf '%s' "$autof" | grep -q 'Nothing else — not what you think the commits do' ||
  note 'implement: the reviewer brief may carry what the run expects it to find'
fixf="$(flat "$skills/fix/SKILL.md")"
printf '%s' "$fixf" | grep -q 'dispatch `gku:reviewer`' || note 'fix: reviews inline, in the session that will fix it'
printf '%s' "$fixf" | grep -q 'facts, never what you expect it to find' ||
  note 'fix: the reviewer brief may carry what the run expects it to find'

# A long test run goes to the runner; the red-then-green proof stays where it is read.
for s in implement fix verify; do
  flat "$skills/$s/SKILL.md" | grep -q 'gku:runner' || note "$s: a long test run fills the session instead of going to gku:runner"
done
printf '%s' "$fixf" | grep -q 'so does the red-then-green proof of step 6' ||
  note 'fix: the red-then-green proof may go to the runner, out of the developer sight'

# Every --deep names the scout, and nothing still promises an unnamed small-model helper.
for s in plan research audit review pr-review; do
  f="$skills/$s/SKILL.md"
  grep -q -e '--deep' "$f" || { note "$s: has no --deep flag to check"; continue; }
  grep -q 'gku:scout' "$f" || note "$s: --deep dispatches an unnamed sub-agent, not gku:scout"
done
for f in "$skills"/*/*.md; do
  [ -f "$f" ] || continue
  if grep -q 'one sub-agent on a small fast model' "$f"; then
    note "$(basename "$(dirname "$f")"): still promises an unnamed sub-agent on a small fast model"
  fi
done

if [ "$fails" -eq 0 ]; then
  printf 'agents: reviewer, runner and scout pinned and self-guarded; review forks; every dispatch names its agent\n'
else
  printf 'agents: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
