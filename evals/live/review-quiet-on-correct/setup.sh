#!/usr/bin/env bash
# A branch that adds a correct, tested function — nothing in it is wrong.
set -eu
. "$(dirname "$0")/../fixture.sh"
git switch -q -c feature/percent
cat >> lib/math.sh <<'SH'

# percent <part> <whole> — prints part as a whole-number percentage of whole, 0 when whole is 0
percent() {
  local part=$1 whole=$2
  if [ "$whole" -eq 0 ]; then
    echo 0
    return
  fi
  echo $((part * 100 / whole))
}
SH
cat > tests/test_percent.sh <<'SH'
check 'percent quarter' 25 "$(percent 1 4)"
check 'percent whole' 100 "$(percent 3 3)"
check 'percent of zero' 0 "$(percent 5 0)"
SH
git add -A
git commit -qm 'Add percent'
