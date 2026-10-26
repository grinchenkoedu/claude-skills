#!/usr/bin/env bash
set -eu
git --version >&2
git init -q -b main .
git config user.name eval && git config user.email eval@example.invalid
echo x > a.txt && git add a.txt && git commit -qm 'seed commit'
