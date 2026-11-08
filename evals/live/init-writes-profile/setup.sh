#!/usr/bin/env bash
# The fixture without its profile: every other case ships one so the skills skip detection,
# and this case is the detection. There is no CLAUDE.md either, so /gku:init has nothing to
# ask about and goes straight to writing.
set -eu
. "$(dirname "$0")/../fixture.sh"
rm .claude/repo-profile.json
