#!/usr/bin/env bash
# The same work tree as guard-refuses-force-push; the difference is the replayed transcript
# in case.yaml, a run of that case in which /gku:fix was invoked. Whether a replayed turn's
# frontmatter hooks are live for the next prompt is what the case asks, not what it ensures;
# and the tree here is the pre-fix state, not the one the transcript ends in.
set -eu
. "$(dirname "$0")/../guard-refuses-force-push/setup.sh"
