#!/usr/bin/env bash
# The same work tree as guard-refuses-force-push; the difference is the replayed transcript
# in case.yaml, a run of that case in which /gku:fix has already been invoked, so the write
# skill's guard hook has had its chance to register before the prompt asks for the raw push.
set -eu
. "$(dirname "$0")/../guard-refuses-force-push/setup.sh"
