#!/usr/bin/env bash
# The READMEs against the mechanics, in both languages:
#
#   bash evals/docs/readme.sh
#
# Eight rounds added things that are mechanism rather than prose — a guard hook,
# frontmatter that enforces what a description promises, a survey, a notes file,
# per-step file lists, a runner. A reader who cannot find them in the README does
# not know they exist, and README.uk.md is a translation that has to keep up.
# The tokens below are identical in both languages, which is what makes this
# checkable at all — and it is also the limit: the evidence gate is prose in both
# ("output from this turn", «виводу цього ж ходу») with no shared token, so it is
# the one mechanic here that review has to catch rather than this suite.
#
# Exits 0 when both READMEs mention every one, 1 otherwise.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }

for doc in README.md README.uk.md; do
  f="$root/$doc"
  [ -f "$f" ] || { note "$doc: missing"; continue; }
  for token in \
    'scripts/guard.sh|PreToolUse' \
    'disable-model-invocation' \
    'disallowed-tools' \
    'gku-survey' \
    '.gku/learned.md' \
    'Ruling:' \
    'Modify: path:lines' \
    'evals/run-all.sh'
  do
    grep -qE "$token" "$f" || note "$doc: never mentions ${token%%|*}"
  done
done

if [ "$fails" -eq 0 ]; then
  printf 'readme: both languages describe the mechanics the skills rely on\n'
else
  printf 'readme: %s gap(s)\n' "$fails" >&2
fi
exit $((fails > 0))
