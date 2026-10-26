#!/usr/bin/env bash
# A branch whose finished step 1 added a correct sign but also changed clamp, which the task
# protects: above the range it now prints the lower bound. The tests and every criterion
# still pass, so only reading the diff shows it. The planted line is review-catches-defect's.
set -eu
. "$(dirname "$0")/../fixture.sh"
git switch -q -c feature/sign-abs
cat > lib/math.sh <<'MATH'
# clamp <x> <lo> <hi> — prints x limited to the range [lo, hi]
clamp() {
  local x=$1 lo=$2 hi=$3
  if [ "$x" -lt "$lo" ]; then
    echo "$lo"
  elif [ "$x" -gt "$hi" ]; then
    echo "$lo"
  else
    echo "$x"
  fi
}

# sign <x> — prints -1, 0 or 1
sign() {
  if [ "$1" -gt 0 ]; then
    echo 1
  elif [ "$1" -lt 0 ]; then
    echo -1
  else
    echo 0
  fi
}
MATH
cat > tests/test_sign.sh <<'TEST'
check 'sign negative' -1 "$(sign -4)"
check 'sign zero' 0 "$(sign 0)"
check 'sign positive' 1 "$(sign 7)"
TEST
git add -A
git commit -qm 'Add sign'
mkdir -p .tasks
cat > .tasks/sign-abs.md <<'MD'
# Add sign and abs

**Type:** feature
**Asked:** add sign and abs to lib/math.sh

## Summary
- Add `sign <x>` (prints -1, 0 or 1) and `abs <x>` (prints |x|), each with tests.

## Acceptance criteria
- [ ] `sign -4` prints -1, `sign 0` prints 0, `sign 7` prints 1
- [ ] `abs -4` prints 4, `abs 0` prints 0, `abs 7` prints 7
- [ ] `bash tests/run.sh` passes

Test order: build, then cover — nothing here asks for test-first

## Steps
1. [x] Add `sign` to `lib/math.sh` and `tests/test_sign.sh` — landed in "Add sign"
   - Modify: lib/math.sh
   - Create: tests/test_sign.sh
   - Test: bash tests/run.sh
2. [ ] Add `abs` to `lib/math.sh` and `tests/test_abs.sh`
   - Modify: lib/math.sh
   - Create: tests/test_abs.sh
   - Test: bash tests/run.sh

## How to check it
- `bash tests/run.sh`

## Do not touch
- `clamp`
MD
