#!/usr/bin/env bash
# The gku review-report hook — SubagentStop on gku:reviewer, from the plugin's
# hooks/hooks.json. /gku:review writes a report under .gku/reports/ whenever it
# finds a blocker (its step 5b), and a forked reviewer forgets that more often
# than not: the answer is the last thing it sends, and prose alone got it to 1
# run in 3. This sends such a review back, once, with the step to do.
#
# Reads the hook's JSON on stdin and exits 2 — the reason on stderr goes to the
# reviewer as its next instruction — only when all of these hold:
#   - stop_hook_active is not true: one send-back at most, never a loop;
#   - no .gku/auto-run at the repository root: an unattended --auto run writes
#     no report, as implement/auto.md tells its reviewer;
#   - the answer's first line, its verdict, names a blocker;
#   - the reviewer's own transcript shows no report written — a Write to, or a
#     Bash redirect into, .gku/reports/review-. A bare mention does not count:
#     the skill text the reviewer reads names that path itself.
# Everything else exits 0 and the reviewer stops.

input="$(cat)"

has_jq=""
command -v jq >/dev/null 2>&1 && has_jq=1

# As in guard.sh: jq where there is one, sed -E otherwise, because BSD sed has
# no \| alternation in a basic regex and would silently extract nothing.
field() { # field <key> <jq path> — that JSON string value, still escaped without jq
  if [ -n "$has_jq" ]; then
    printf '%s' "$input" | jq -r "$2 // empty" 2>/dev/null
  else
    printf '%s' "$input" | sed -E -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -1
  fi
}

# A retry already: let it stop, whatever it did.
printf '%s' "$input" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

# Nobody is watching: the marker sits at the primary repository's root, found
# the way guard.sh finds it (--git-common-dir, so a worktree finds it too).
dir="$(field cwd '.cwd')"
dir="${dir:-$PWD}"
root=""
common="$(cd "$dir" 2>/dev/null && git rev-parse --git-common-dir 2>/dev/null)"
[ -n "$common" ] && root="$(cd "$dir" && cd "$common/.." 2>/dev/null && pwd)"
[ -f "${root:-$dir}/.gku/auto-run" ] && exit 0

# The verdict is the first line with text in it. Without jq the message is
# still JSON-escaped, so its \n escapes become the line breaks here.
if [ -n "$has_jq" ]; then
  verdict="$(printf '%s' "$input" | jq -r '.last_assistant_message // empty' 2>/dev/null | awk 'NF { print; exit }')"
else
  verdict="$(field last_assistant_message '.last_assistant_message' | awk '{ gsub(/\\n/, "\n"); print }' | awk 'NF { print; exit }')"
fi
printf '%s' "$verdict" | grep -Eiq '(^|[^a-z])blockers?([^a-z]|$)' || exit 0
printf '%s' "$verdict" | grep -Eiq '(^|[^a-z])(no|zero|0) blockers?' && exit 0

# Written already? Only the Write tool aimed at the report, or a Bash redirect or tee whose
# target is the report, counts — a Read of an older one, or a > elsewhere in the same command,
# does not. Claude Code writes a tool call as "name":"Write","input":{"file_path":….
transcript="$(field agent_transcript_path '.agent_transcript_path')"
# The docs show the path with a literal ~/ in it; the shell will not expand that.
[ "${transcript#\~/}" != "$transcript" ] && transcript="$HOME/${transcript#\~/}"
if [ -f "$transcript" ] && grep -Eq \
  -e '"name"[[:space:]]*:[[:space:]]*"Write"[[:space:]]*,[[:space:]]*"input"[[:space:]]*:[[:space:]]*\{[[:space:]]*"file_path"[[:space:]]*:[[:space:]]*"[^"]*\.gku/reports/review-' \
  -e '"command"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*(>>?|tee( -a)?)[[:space:]]*(\\")?[^"[:space:];|&]*\.gku/reports/review-' \
  "$transcript"; then
  exit 0
fi

printf '%s\n' "This review names a blocker and no report was written. Do /gku:review's step 5b now: write the review in full to .gku/reports/review-<branch-slug>-<timestamp>.md with the Write tool, as reference/reports.md says, then return the whole review again as your final answer, ending with the report's absolute path." >&2
exit 2
