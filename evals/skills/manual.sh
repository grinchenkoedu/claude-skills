#!/usr/bin/env bash
# /gku:plan --manual, asserted: run it from anywhere.
#
#   bash evals/skills/manual.sh
#
# --manual writes a plan for a person to build by hand — in a repository that
# does not want generated code, or for someone learning the codebase. That only
# works while three skills agree on one contract: plan writes the file and the
# `Mode: manual` marker in its header, implement reads the marker and asks
# instead of building, and review stops offering a skill that commits. The
# contract is prose in three files, so it is exactly the kind of thing that
# drifts apart one edit at a time.
#
# The file also has to survive a compaction and a new session, which is what the
# Progress / Q&A / Resume prompt sections are for, and the developer has to be
# told to commit each step themselves, since nothing in this mode does it.
#
# Exits 0 when it holds, 1 otherwise.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
skills="$root/plugins/gku/skills"
for s in plan implement review; do
  [ -f "$skills/$s/SKILL.md" ] || { printf 'no %s/SKILL.md under %s\n' "$s" "$skills" >&2; exit 1; }
done

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
# Prose wraps at the file's width, and the phrases below are dressed in
# backticks and bold in the source — flatten and undress before matching, as
# evals/skills/file-lists.sh does with `Modify:`.
flat() { tr '\n' ' ' < "$1" | tr -d '`*' | tr -s ' '; }
planf="$(flat "$skills/plan/SKILL.md")"
impf="$(flat "$skills/implement/SKILL.md")"
revf="$(flat "$skills/review/SKILL.md")"
# -e, because half the phrases below start with the mode's own leading dashes
# and grep would read them as options.
has() { printf '%s' "$1" | grep -qF -e "$2"; }

# --- /gku:plan: the mode has to be reachable and say what it writes ----------

grep '^argument-hint:' "$skills/plan/SKILL.md" | grep -q -- '--manual' \
  || note 'plan: --manual is missing from argument-hint, so nothing advertises it'
has "$planf" '- --manual —' || note 'plan: --manual has no entry in the Arguments list'
has "$planf" '## Step 6b' || note 'plan: --manual has no section of its own'

# What makes it a manual plan rather than a plan with a different name. Without
# the first of these the mode writes an implementation to paste, which is what
# both of its audiences — an AI-agnostic repository and a learner — are avoiding.
has "$planf" 'Shapes, never paste-ready code' \
  || note 'plan: --manual may write paste-ready code, so the mode buys nothing'
has "$planf" 'Detail aimed at someone who has not read the code' \
  || note 'plan: --manual writes for someone who already knows the codebase'
has "$planf" 'Nothing here commits' \
  || note 'plan: --manual never says that nothing in the file commits for the developer'
has "$planf" 'Then commit this step yourself' \
  || note 'plan: the manual step shape drops the per-step commit warning'

# The marker the other two skills read. Everything below depends on it.
has "$planf" 'Mode: manual' || note 'plan: the manual template has no Mode: manual marker'

# The file as the session memory: a manual build spans days and compactions.
has "$planf" '## Progress' || note 'plan: the manual template has no progress section to resume from'
has "$planf" '## Q&A' || note 'plan: the manual template keeps no record of what was asked and answered'
has "$planf" '## Resume prompt' || note 'plan: the manual template gives a new session nothing to start from'
has "$planf" 'do not write the code for me, and do not commit anything' \
  || note 'plan: the resume prompt lets the next session write the code it was meant to explain'

# The step keeps the lines the readers grep (evals/skills/file-lists.sh) and
# gains the three that make it followable by hand.
for part in 'Shape:' 'Why:' 'Prove it:'; do
  grep -qE "^ +- $part" "$skills/plan/SKILL.md" || note "plan: the manual step shape has no $part line"
done

# Handing it over. Naming /gku:implement here is how a manual plan gets built
# automatically five minutes after it was written.
has "$planf" 'Its next command is not /gku:implement' \
  || note 'plan: a manual plan is handed off with the command that would build it for them'
has "$planf" '--manual writes for a person, and warns them to commit' \
  || note 'plan: the rules do not carry the mode, so a reader who skips step 6b never meets it'

# --- /gku:implement: the marker is a stop ------------------------------------

has "$impf" 'Mode: manual in its header means stop and ask' \
  || note 'implement: builds a manual plan without asking, which spends what it was written to buy'
has "$impf" 'only on an explicit yes' \
  || note 'implement: no explicit consent needed before building a manual plan'
has "$impf" 'a task file marked Mode: manual' \
  || note 'implement: --auto is not stopped by a manual plan, and there is nobody there to ask'

# --- /gku:review: it reviews hand-written code, and still never commits ------

has "$revf" 'nothing committed and nothing uncommitted' \
  || note 'review: reports "no changes" mid-step of a hand-built change, whose work is all uncommitted'
has "$revf" 'A hand-written branch has none by design' \
  || note 'review: treats missing Ruling: lines on a hand-built branch as a finding'
has "$revf" 'do not offer /gku:fix' \
  || note 'review: ends a hand-built branch by offering a skill that commits'

if [ "$fails" -eq 0 ]; then
  printf 'manual: plan writes it for a person, implement asks first, review hands it back\n'
else
  printf 'manual: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
