#!/usr/bin/env bash
# implement-auto-reading-trap's branch: step 1 is ticked and committed, and its commit also
# broke clamp above the range, which the task protects. Here a person builds step 2 and then
# asks for a review, so the review runs after a build has filled the session.
set -eu
. "$(dirname "$0")/../implement-auto-reading-trap/setup.sh"
