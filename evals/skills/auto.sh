#!/usr/bin/env bash
# /gku:implement --auto, asserted: run it from anywhere.
#
#   bash evals/skills/auto.sh
#
# --auto is the one mode that pushes and opens a pull request without a person
# reading the diff first, so what it must never do matters more than what it
# does: no merge, no deploy, no --force. The rest of this suite holds the shape
# that makes an unattended run recoverable — the questions asked up front, the
# review-fix-test cycle with a bound on it, the short list of things worth
# stopping for, and work left in a pushed draft rather than a halted session.
#
# Exits 0 when they hold, 1 otherwise.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
imp="$root/plugins/gku/skills/implement/SKILL.md"
[ -f "$imp" ] || { printf 'no implement/SKILL.md at %s\n' "$imp" >&2; exit 1; }

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
# Prose wrapped at the file's width: match against a flattened copy, as
# evals/reference/claims.sh does.
flat="$(tr '\n' ' ' < "$imp" | tr -s ' ')"
has() { printf '%s' "$flat" | grep -qF "$1"; }

# The mode has to be reachable: a section nobody is told about is dead prose.
grep '^argument-hint:' "$imp" | grep -q -- '--auto' || note 'implement: --auto is missing from argument-hint, so nothing advertises it'
has '## `--auto`' || note 'implement: --auto has no section of its own'

# The bans. These are the reason the mode is safe to hand a repository.
has 'never merges and it never deploys' || note 'implement: --auto does not rule out merging and deploying'
has 'Never merge, never deploy, never touch a live system' || note 'implement: the rules no longer ban merge and deploy outright'
has 'remain banned' || note 'implement: --auto does not carry the --force/--amend/--no-verify ban forward'

# The shape of an unattended run.
has 'Ask everything at the start' || note 'implement: --auto does not front-load its questions, so it will stop mid-run instead'
has 'at most three rounds' || note 'implement: the review-fix-test cycle has no bound and can grind forever'
has 'Review the diff from scratch' || note 'implement: --auto has no review step, so nothing reads the diff before the pull request'
has 'This is a self-review: say so' || note 'implement: --auto passes its own review off as an independent one'
has '### When an autonomous run stops' || note 'implement: --auto never says what is worth stopping for'
has 'Stopping is not halting' || note 'implement: a stopped run leaves the work nowhere the developer can pick it up'

# What an unattended run leaves behind. Nobody watched it, so a nit it skipped
# or a thing it half-finished exists only if it was written down at the time —
# and only reaches the developer if it travels somewhere git does not ignore.
# Careful: a bare '## Notes' is a substring of this section's own '### Notes'
# heading, which would leave this green with the instruction gone.
has 'task file under `## Notes`' || note 'implement: --auto keeps no notes, so what it left alone is lost'
has 'the moment it comes up' || note 'implement: notes are reconstructed at the end rather than written as they happen'
has "pull request's body under **Notes**" || note 'implement: notes stay in the git-ignored task file and reach nobody'
has 'warning the developer before it says it is finished' || note 'implement: --auto can report done without putting the notes in front of anyone'

# Several branches, still readable in order.
has 'Depends on #' || note 'implement: chained pull requests are not linked to the one they sit on'
has 'draft otherwise' || note 'implement: opens a pull request as ready whether or not the criteria are met'

if [ "$fails" -eq 0 ]; then
  printf 'auto: --auto runs the cycle, stops for a person, and never merges or deploys\n'
else
  printf 'auto: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
