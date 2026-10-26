#!/usr/bin/env bash
# A branch whose one commit breaks clamp above the range; the tests do not cover it.
set -eu
. "$(dirname "$0")/../fixture.sh"
git switch -q -c refactor/clamp
cat > lib/math.sh <<'SH'
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
SH
git commit -qam 'Tidy clamp'
