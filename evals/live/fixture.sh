#!/usr/bin/env bash
# The project every case starts from: a small bash library with a test runner,
# a profile so the skills skip detection, and one commit on main. A case's own
# setup.sh sources this, then adds the commit or the branch it is about.
set -eu

git init -q -b main .
git config user.name eval
git config user.email eval@example.invalid

mkdir -p lib tests .claude
cat > lib/math.sh <<'SH'
# clamp <x> <lo> <hi> — prints x limited to the range [lo, hi]
clamp() {
  local x=$1 lo=$2 hi=$3
  if [ "$x" -lt "$lo" ]; then
    echo "$lo"
  elif [ "$x" -gt "$hi" ]; then
    echo "$hi"
  else
    echo "$x"
  fi
}
SH
cat > tests/run.sh <<'SH'
#!/usr/bin/env bash
# Runs every tests/test_*.sh and prints one summary line.
cd "$(dirname "$0")/.." || exit 1
. lib/math.sh
pass=0 fail=0
check() { # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: expected $2, got $3"; fi
}
for t in tests/test_*.sh; do . "$t"; done
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
SH
cat > tests/test_clamp.sh <<'SH'
check 'clamp inside' 5 "$(clamp 5 0 10)"
check 'clamp below' 0 "$(clamp -3 0 10)"
SH
cat > .claude/repo-profile.json <<'JSON'
{
  "platform": "macos",
  "shell": "bash",
  "family": "other",
  "language": "bash",
  "baseBranch": "main",
  "standardsDoc": null,
  "exec": { "kind": "host", "prefix": "", "note": "plain bash, nothing to containerise" },
  "install": null,
  "lint": null,
  "test": "bash tests/run.sh",
  "testScoped": "bash tests/run.sh",
  "build": null,
  "runtime": { "kind": "library", "how": null },
  "hasDatabase": false,
  "timeoutTool": null
}
JSON
printf '.claude/repo-profile.json\n.gku/\n.tasks/\n' > .gitignore
git add -A
git commit -qm 'Add clamp with tests'
