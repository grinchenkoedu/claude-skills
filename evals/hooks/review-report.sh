#!/usr/bin/env bash
# Behaviour cases for plugins/gku/scripts/review-report.sh — run them from anywhere:
#
#   bash evals/hooks/review-report.sh
#
# The hook sends a blocker review back to gku:reviewer, once, when it wrote no
# report. Every case is "expected exit code | stop_hook_active | the verdict
# line | what the reviewer's transcript holds | whether .gku/auto-run exists".
# The table runs twice: as the machine is, and with jq off the PATH, because
# the jq-less half decodes the message itself and is the half that goes wrong
# quietly.
#
# Exits 0 when every case matches, 1 otherwise, naming each mismatch.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
hook="${REVIEW_REPORT_HOOK:-$root/plugins/gku/scripts/review-report.sh}"
[ -x "$hook" ] || { printf 'no hook at %s\n' "$hook" >&2; exit 1; }

work="$(mktemp -d)"
nojq="$work/nojq"; mkdir -p "$nojq"
for t in cat sed grep head git awk; do
  for c in /bin/$t /usr/bin/$t; do [ -x "$c" ] && ln -sf "$c" "$nojq/$t" && break; done
done

# What a reviewer's transcript can hold, one JSON line each, as Claude Code writes them.
tr_dir="$work/transcripts"; mkdir -p "$tr_dir"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"git diff main...HEAD"}}]}}' > "$tr_dir/none"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Write","input":{"file_path":"/w/.gku/reports/review-x-20261101.md","content":"**1 blocker first**"}}]}}' > "$tr_dir/write"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"mkdir -p .gku/reports && cat > \"/w/.gku/reports/review-x.md\" <<'"'"'EOF'"'"'\n**1 blocker first**\nEOF"}}]}}' > "$tr_dir/bash"
printf '%s\n' '{"type":"user","message":{"content":"It goes to `.gku/reports/review-<branch-slug>-<timestamp>.md` — never the repository root."}}' > "$tr_dir/mention"

fails=0
run() { # run <label> <want> <active> <verdict> <transcript> <marker> [PATH]
  local label="$1" want="$2" active="$3" verdict="$4" tr="$5" marker="$6" path="${7-}" dir got payload
  dir="$work/cwd"; rm -rf "$dir"; mkdir -p "$dir"
  [ "$marker" = yes ] && mkdir -p "$dir/.gku" && printf 'started\n' > "$dir/.gku/auto-run"
  payload="$(printf '{"cwd":"%s","hook_event_name":"SubagentStop","stop_hook_active":%s,"agent_type":"gku:reviewer","agent_transcript_path":"%s","last_assistant_message":"%s\\n\\nThe rest of the review, with a \\"quote\\"."}' \
    "$dir" "$active" "$tr_dir/$tr" "$verdict")"
  if [ -n "$path" ]; then
    printf '%s' "$payload" | PATH="$path" /bin/bash "$hook" >/dev/null 2>&1
  else
    printf '%s' "$payload" | "$hook" >/dev/null 2>&1
  fi
  got=$?
  if [ "$got" != "$want" ]; then
    printf 'FAIL  %-6s want=%s got=%s  active=%s verdict=%s transcript=%s marker=%s\n' \
      "$label" "$want" "$got" "$active" "$verdict" "$tr" "$marker"
    fails=$((fails + 1))
  fi
}

cases() {
  local label="$1" path="${2-}"
  while IFS='|' read -r want active verdict tr marker; do
    case "$want" in ''|'#'*) continue ;; esac
    run "$label" "$want" "$active" "$verdict" "$tr" "$marker" "$path"
  done <<'TABLE'
# sent back — a blocker and no report, however the reviewer phrased the verdict
2|false|**2 blockers first**|none|no
2|false|**1 blocker first**|none|no
2|false|**Don't push yet: there's 1 blocker.**|none|no
# sent back — the skill text names the path, which is not a write
2|false|**1 blocker first**|mention|no
# sent back — no transcript to read is no proof of a report
2|false|**1 blocker first**|missing|no
# let it stop — the report is there, written either way
0|false|**1 blocker first**|write|no
0|false|**2 blockers first**|bash|no
# let it stop — no blocker in the verdict
0|false|**Ready to push**|none|no
0|false|**Ready, with 2 warnings worth a look**|none|no
0|false|**Ready to push** — no blockers|none|no
# let it stop — a retry already, or nobody watching
0|true|**2 blockers first**|none|no
0|false|**2 blockers first**|none|yes
TABLE
}

cases 'jq'
[ -x "$nojq/sed" ] && [ -x "$nojq/awk" ] && cases 'no-jq' "$nojq"

rm -rf "$work"
if [ "$fails" -eq 0 ]; then
  printf 'review-report: all cases pass\n'
else
  printf 'review-report: %s case(s) failed\n' "$fails" >&2
fi
exit $((fails > 0))
