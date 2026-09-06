#!/usr/bin/env bash
# Behaviour cases for plugins/gku/scripts/guard.sh — run them from anywhere:
#
#   bash evals/guard/cases.sh
#
# Every case is "expected exit code | the command the hook is asked about".
# The table runs twice: once as the machine is, and once with jq off the PATH,
# because the guard's jq-less fallback is the half that silently refused
# nothing when its regex was wrong.
#
# Exits 0 when every case matches, 1 otherwise, naming each mismatch.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
guard="$root/plugins/gku/scripts/guard.sh"
[ -x "$guard" ] || { printf 'no guard at %s\n' "$guard" >&2; exit 1; }

# A directory with no profile in it, so only main and master are base branches
# and the result does not depend on whose checkout this is.
work="$(mktemp -d)"
# The jq-less PATH: the tools the guard needs, and not jq.
nojq="$work/nojq"; mkdir -p "$nojq"
for t in cat sed grep head; do
  for c in /bin/$t /usr/bin/$t; do [ -x "$c" ] && ln -sf "$c" "$nojq/$t" && break; done
done

fails=0
run() { # run <label> <expected> <json-escaped command> [PATH]
  local label="$1" want="$2" cmd="$3" path="${4-}" got
  if [ -n "$path" ]; then
    ( cd "$work" && printf '{"tool_input":{"command":"%s"}}' "$cmd" | PATH="$path" /bin/bash "$guard" ) >/dev/null 2>&1
  else
    ( cd "$work" && printf '{"tool_input":{"command":"%s"}}' "$cmd" | "$guard" ) >/dev/null 2>&1
  fi
  got=$?
  if [ "$got" != "$want" ]; then
    printf 'FAIL  %-8s want=%s got=%s  %s\n' "$label" "$want" "$got" "$cmd"
    fails=$((fails + 1))
  fi
}

cases() {
  local label="$1" path="${2-}"
  while IFS='|' read -r want cmd; do
    case "$want" in ''|'#'*) continue ;; esac
    run "$label" "$want" "$cmd" "$path"
  done <<'TABLE'
# refused — a forced push, however it is spelled
2|git push --force origin x
2|git push --force-with-lease
2|git push -f origin x
2|cd sub && git push --force
# refused — rewriting or skipping
2|git commit --amend -m \"x\"
2|git commit --no-verify -m \"x\"
2|git push --no-verify
# refused — a push to the base branch, in each of its shapes
2|git push origin main
2|git push -u origin master
2|git push origin HEAD:main
2|git push origin master:master
2|git push origin +main
2|git push origin HEAD:refs/heads/main
2|git push origin +refs/heads/master
2|git push --delete origin main
# allowed — an ordinary branch whose name merely contains one
0|git push origin feature/x
0|git push origin feature/main-thing
0|git push origin main-thing
0|git push origin domain
# allowed — talk about a flag is not use of it
0|git commit -m \"never pass --no-verify\"
0|git commit -m \"push --force is banned here\"
0|git commit -m 'do not --amend'
# allowed — and the flags outside the quotes are still seen
2|git commit -m \"msg\" && git push --force
# allowed — nothing to do with git, or nothing to read
0|ls -la
0|rm -rf build
TABLE
}

cases 'jq'
[ -x "$nojq/sed" ] && cases 'no-jq' "$nojq"

rm -rf "$work"
if [ "$fails" -eq 0 ]; then
  printf 'guard: all cases pass\n'
else
  printf 'guard: %s case(s) failed\n' "$fails" >&2
fi
exit $((fails > 0))
