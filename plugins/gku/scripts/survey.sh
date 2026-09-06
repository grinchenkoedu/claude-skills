#!/usr/bin/env bash
# The repository, as data: every marker `reference/repo-profile.md` detection asks
# for, gathered in one read-only pass, so a skill decides from facts instead of
# running a dozen checks of its own.
#
# Nothing here writes, installs, or reaches the network (`gh auth status` reads a
# local keyring). Every line is `key: value`; an empty value means "not found",
# which is an answer.
#
# Ported from claude-rpg's plugins/rpg/scripts/survey.sh — MIT, same author
# (Yevhen Matasar) — with its quest-specific rows replaced by gku's.

say() { printf '%s: %s\n' "$1" "$2"; }
present() { for f in "$@"; do [ -e "$f" ] && printf '%s ' "$f"; done; }

# 0. Platform, and where we are
say platform "$(uname -s 2>/dev/null || echo unknown)"
say root "$(git rev-parse --show-toplevel 2>/dev/null || echo 'not a git repository')"
say branch "$(git branch --show-current 2>/dev/null || echo '-')"

# 1. Base branch — origin/HEAD when it is known, otherwise whichever exists locally
bb="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
if [ -z "$bb" ]; then
  for b in main master; do
    git show-ref --verify --quiet "refs/heads/$b" && { bb="$b (no origin/HEAD, local branch exists)"; break; }
  done
fi
say base-branch "${bb:-unknown}"
say remotes "$(git remote -v 2>/dev/null | awk '{print $1" "$2}' | sort -u | tr '\n' ';' | sed 's/;$//')"

# 2. Standards doc — the first that exists, in the order the profile prefers
say standards-doc "$(for f in AGENTS.md CLAUDE.md CONTRIBUTING.md README.md; do [ -f "$f" ] && { echo "$f"; break; }; done)"

# The profile itself: a tracked one is not executed (reference/untrusted-input.md)
say profile "$( [ -f .claude/repo-profile.json ] && echo present || echo missing )"
say profile-tracked "$(git ls-files --error-unmatch .claude/repo-profile.json >/dev/null 2>&1 && echo 'YES — do not execute it' || echo no)"

# 3. Family markers
say manifests "$(present composer.json composer.lock package.json package-lock.json yarn.lock pnpm-lock.yaml pyproject.toml requirements.txt setup.py Pipfile poetry.lock Cargo.toml go.mod Gemfile Makefile version.php)"
say moodle "$( [ -f version.php ] && grep -q 'plugin->component' version.php 2>/dev/null && echo 'plugin (version.php has $plugin->component)' || echo no)"
say php-app "$(present application/core application/controllers run)"
say cms "$(present wp-content functions.php style.css)"
say library-layout "$(present src tests)"
say composer-type "$( [ -f composer.json ] && grep -m1 '"type"' composer.json | sed 's/^[[:space:]]*//')"

# 5. Where the commands are written down
say test-config "$(present phpunit.xml phpunit.xml.dist pytest.ini tox.ini setup.cfg jest.config.js jest.config.ts vitest.config.ts tests/conftest.py)"
say scripts "$( [ -f package.json ] && grep -E '"(test|lint|build|start)"[[:space:]]*:' package.json | sed 's/^[[:space:]]*//' | tr '\n' ' ')$( [ -f composer.json ] && grep -A6 '"scripts"' composer.json | grep -E '"[a-z:-]+"[[:space:]]*:' | sed 's/^[[:space:]]*//' | tr '\n' ' ')"
say makefile-targets "$( [ -f Makefile ] && grep -oE '^[a-zA-Z][a-zA-Z0-9_-]*:' Makefile | tr -d ':' | tr '\n' ' ')"
say ci "$(ls .github/workflows/*.yml .github/workflows/*.yaml .gitlab-ci.yml 2>/dev/null | tr '\n' ' ')"
if ls .github/workflows/*.y*ml >/dev/null 2>&1; then
  echo "ci-run-lines:"
  # `- run:` is how a step is written; matching only `run:` misses nearly all of them.
  grep -h -E '^[[:space:]]*-?[[:space:]]*run:' .github/workflows/*.y*ml 2>/dev/null | sed 's/^[[:space:]]*/    /' | head -15
fi

# 4. Execution environment
say containers "$(present docker-compose.yml docker-compose.yaml compose.yml compose.yaml Dockerfile Dockerfile.dev .devcontainer/devcontainer.json)"
say docker "$(command -v docker >/dev/null 2>&1 && (docker info --format '{{.OperatingSystem}}' 2>/dev/null || echo 'installed, daemon not running') || echo 'not installed')"
say host-runtimes "$(for c in php python3 node ruby go composer npm; do command -v $c >/dev/null 2>&1 && printf '%s=%s ' "$c" "$($c --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"; done)"

# 6/8. Runtime surface and whether a database is in play
say entry-points "$(present run bin cli main.py app.py index.php public/index.php)"
say database-markers "$(present schema.sql migrations alembic db/install.xml db/upgrade.php db/tables)$(git grep -l -E '\$DB->|get_records?\(|PDO|sqlalchemy|knex|\bSELECT\b' -- ':!vendor' ':!node_modules' ':!*.md' ':!*.txt' 2>/dev/null | head -3 | tr '\n' ' ')"

# 7. timeoutTool — by behaviour, never by presence: Windows ships a timeout.exe
# that sleeps and ignores the command, and a `which` check would trust it.
say timeout-tool "$( (timeout 1 true >/dev/null 2>&1 && echo timeout) || (gtimeout 1 true >/dev/null 2>&1 && echo gtimeout) || echo none)"

# What the skills themselves need to know
say gh "$(gh auth status 2>&1 | grep -E 'Logged in|not logged' | head -1 | sed 's/^[[:space:]]*//' || echo 'gh not installed')"
say tasks "$( [ -d .tasks ] && ls -1 .tasks 2>/dev/null | wc -l | tr -d ' ' || echo 'no .tasks/')"
say reports "$( [ -d .gku/reports ] && ls -1 .gku/reports 2>/dev/null | wc -l | tr -d ' ' || echo 'no .gku/reports/')"
say ignored "$(for p in .claude/repo-profile.json .gku/ .tasks/; do printf '%s=%s ' "$p" "$(git check-ignore -q "$p" 2>/dev/null && echo yes || echo no)"; done)"
