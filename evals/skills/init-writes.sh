#!/usr/bin/env bash
# /gku:init's write list and its first step agree — run it from anywhere:
#
#   bash evals/skills/init-writes.sh
#
# Step 1 of init reads the profile or detects it and caches it, as
# reference/repo-profile.md says every skill does. Its Rules then list what the
# skill may write; a list that names only CLAUDE.md and the AGENTS.md stub reads
# as forbidding the cache, and a model that takes the rule literally detects the
# profile and then refuses to write it (a headless run did exactly that on
# 2026-11-08). So the rule has to name the cache, and step 1 has to keep asking
# for it.
#
# Exits 0 when they agree, 1 otherwise.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
init="$root/plugins/gku/skills/init/SKILL.md"
ref="$root/plugins/gku/reference/repo-profile.md"
[ -f "$init" ] || { printf 'no init/SKILL.md\n' >&2; exit 1; }

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
# Prose wrapped at the file's width: match against a flattened copy, as the other suites do.
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }
initf="$(flat "$init")"

# Step 1 still asks for the cache, and the reference still says detection ends in a write.
printf '%s' "$initf" | grep -q 'cache it per `reference/repo-profile.md`' || note 'init: step 1 no longer caches the profile'
flat "$ref" | grep -q 'After detection, write the file' || note 'repo-profile: detection no longer ends in writing the cache'

# The write list is the bold sentence that begins "Only ever write", up to the closing `**`;
# a single `*` of italics inside it must not cut the match short.
rule="$(printf '%s' "$initf" | grep -o 'Only ever write.*' | sed 's/\*\*.*//')"
[ -n "$rule" ] || note 'init: the Rules no longer say what the skill may write'
printf '%s' "$rule" | grep -q 'repo-profile.json' || note "init: the write list forbids the cache step 1 asks for — '$rule'"

if [ "$fails" -eq 0 ]; then
  printf 'init-writes: the write list allows the profile cache step 1 asks for\n'
else
  printf 'init-writes: %s problem(s)\n' "$fails" >&2
fi
exit $((fails > 0))
