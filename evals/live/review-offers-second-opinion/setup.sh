#!/usr/bin/env bash
# review-catches-defect's scaffold — a blocker review on a typed /gku:review — on a machine
# where gku-agents lists at least one agent CLI, so the second-opinion offer has something to
# name. With nothing installed the offer cannot fire and a pass would mean nothing: stop here,
# with the reason, rather than run a case that fails for the wrong one.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
agents="$("$here/../../../plugins/gku/bin/gku-agents" 2>/dev/null || true)"
if [ -z "$agents" ]; then
  printf 'review-offers-second-opinion: no agent CLI installed (agy, copilot or opencode), so there is nothing to offer — case not run\n' >&2
  exit 1
fi
printf 'agents the offer can name:\n%s\n' "$agents" >&2
. "$here/../review-catches-defect/setup.sh"
# The one case that wants the offer: the scaffold it sources turns it off, so turn it back on.
rm -f .gku/no-second-opinion
