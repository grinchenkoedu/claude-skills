#!/usr/bin/env bash
# A branch that adds a correct, tested function — nothing in it is wrong. Correct includes its
# input: an unvalidated argument in $(( )) runs as code, which the security checklist rates a
# WARNING even with no untrusted caller yet, so percent takes decimal whole numbers of at most
# 15 digits, so part * 100 cannot overflow, read in base 10, since bash reads 010 as octal;
# anything else returns 1.
set -eu
. "$(dirname "$0")/../fixture.sh"
git switch -q -c feature/percent
cat >> lib/math.sh <<'SH'

# percent <part> <whole> — prints part as a percentage of whole, rounded down; 0 when whole is
# 0. Both must be decimal whole numbers of at most 15 digits, or it prints nothing and
# returns 1.
percent() {
  local part=$1 whole=$2
  case $part in '' | *[!0-9]* | ????????????????*) return 1 ;; esac
  case $whole in '' | *[!0-9]* | ????????????????*) return 1 ;; esac
  if [ $((10#$whole)) -eq 0 ]; then
    echo 0
    return
  fi
  echo $((10#$part * 100 / 10#$whole))
}
SH
cat > tests/test_percent.sh <<'SH'
check 'percent quarter' 25 "$(percent 1 4)"
check 'percent whole' 100 "$(percent 3 3)"
check 'percent of zero' 0 "$(percent 5 0)"
check 'percent rounds down' 66 "$(percent 2 3)"
check 'percent reads a leading zero as decimal' 100 "$(percent 010 10)"
check 'percent rejects a non-number' 'rc=1' "$(percent 'x[1]' 4; echo "rc=$?")"
check 'percent rejects a negative' 'rc=1' "$(percent 1 -4; echo "rc=$?")"
check 'percent rejects an empty whole' 'rc=1' "$(percent 1 ''; echo "rc=$?")"
check 'percent rejects 16 digits' 'rc=1' "$(percent 1000000000000000 1; echo "rc=$?")"
SH
git add -A
git commit -qm 'Add percent'
# This case measures the review alone. With an agent CLI installed the second-opinion offer
# would take the session's last message, which the verdict regex reads; the marker keeps it
# quiet.
mkdir -p .gku && : > .gku/no-second-opinion
