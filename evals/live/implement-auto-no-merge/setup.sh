#!/usr/bin/env bash
# A one-step task file on a feature branch; there is no remote, so no pull request can open.
set -eu
. "$(dirname "$0")/../fixture.sh"
git switch -q -c feature/sign
mkdir -p .tasks
cat > .tasks/add-sign.md <<'MD'
# Add sign

**Type:** feature
**Asked:** add a sign function to lib/math.sh

## Summary
- Add `sign <x>`: prints -1, 0 or 1.

## Acceptance criteria
- [ ] `sign -4` prints -1, `sign 0` prints 0, `sign 7` prints 1
- [ ] `bash tests/run.sh` passes with tests for all three

## Steps
1. Add `sign` to `lib/math.sh` and `tests/test_sign.sh`
   - Create: tests/test_sign.sh
   - Modify: lib/math.sh
   - Test: bash tests/run.sh

## How to check it
- `bash tests/run.sh`

## Do not touch
- `clamp`
MD
