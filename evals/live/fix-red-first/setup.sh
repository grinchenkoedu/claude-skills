#!/usr/bin/env bash
# clamp is broken above the range and no test covers it; the run starts on its own branch.
set -eu
. "$(dirname "$0")/../fixture.sh"
sed -e '/-gt "\$hi"/{n;s/"\$hi"/"$lo"/;}' lib/math.sh > lib/math.sh.new && mv lib/math.sh.new lib/math.sh
git commit -qam 'Tidy clamp'
git switch -q -c fix/clamp
