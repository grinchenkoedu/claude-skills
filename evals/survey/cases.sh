#!/usr/bin/env bash
# Cases for plugins/gku/bin/gku-survey — run them from anywhere:
#
#   bash evals/survey/cases.sh
#
# The survey answers the questions reference/repo-profile.md's detection asks, so
# what is checked here is that each answer follows the fixture it is given, that a
# directory which is not a repository does not break it, and that it writes nothing.
#
# Exits 0 when every case matches, 1 otherwise, naming each mismatch.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
survey="$root/plugins/gku/bin/gku-survey"
[ -x "$survey" ] || { printf 'no survey at %s\n' "$survey" >&2; exit 1; }

# Fixtures are temporary directories; clean them up however this run ends.
# An array, not a string: a temporary directory can contain a space, and the
# word splitting that would follow is an rm -rf of the wrong paths.
fixtures=()
cleanup() { [ "${#fixtures[@]}" -gt 0 ] && rm -rf "${fixtures[@]}"; }
trap cleanup EXIT INT TERM

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
row()  { printf '%s\n' "$out" | sed -n "s/^$1: //p"; }
want() { # want <row> <substring>
  case "$(row "$1")" in
    *"$2"*) ;;
    *) note "$3: $1 should mention '$2', got '$(row "$1")'" ;;
  esac
}
wantnot() { # wantnot <row> <substring>
  case "$(row "$1")" in
    *"$2"*) note "$3: $1 should not mention '$2', got '$(row "$1")'" ;;
  esac
}

# A library-shaped PHP fixture with a database call and a compose file.
fix="$(mktemp -d)"; fixtures+=("$fix")
mkdir -p "$fix/src" "$fix/tests" "$fix/.github/workflows"
printf '{"name":"x/y","type":"library"}\n'          > "$fix/composer.json"
printf '<phpunit/>\n'                                > "$fix/phpunit.xml"
printf '<?php $DB->get_record("user", []);\n'        > "$fix/src/Repo.php"
printf 'services:\n  app:\n    image: php:7.4\n'     > "$fix/docker-compose.yml"
printf 'jobs:\n  t:\n    steps:\n      - run: vendor/bin/phpunit\n' > "$fix/.github/workflows/ci.yml"
printf '# Conventions\n$DB-> is only mentioned here.\n' > "$fix/CONTRIBUTING.md"
( cd "$fix" && git init -q . && git add -A && git -c user.email=t@e -c user.name=t commit -qm init )

out="$(cd "$fix" && bash "$survey")"
want composer-type   'library'        'php library'
want test-config     'phpunit.xml'    'php library'
want library-layout  'src'            'php library'
want containers      'docker-compose' 'php library'
want ci              'ci.yml'         'php library'
want standards-doc   'CONTRIBUTING.md' 'php library'
want moodle          'no'             'php library'
want database-markers 'src/Repo.php'  'php library'
wantnot database-markers 'CONTRIBUTING.md' 'php library'   # prose about a database is not a database
printf '%s\n' "$out" | grep -q 'vendor/bin/phpunit' || note "php library: the CI run lines should be quoted"
case "$(row timeout-tool)" in timeout|gtimeout|none) ;; *) note "php library: timeout-tool must be timeout, gtimeout or none" ;; esac
# A library has no application entry point: the php-app row must be empty, or the family table,
# which checks php-app before php-library, would take it for an application.
[ -z "$(row php-app)" ] || note "php library: php-app row must be empty, got '$(row php-app)'"

# It writes nothing: the fixture is unchanged after the run.
( cd "$fix" && [ -z "$(git status --porcelain)" ] ) || note 'the survey changed the tree it surveyed'

# A library with no composer type and a demo page under public/. Composer takes a missing type
# as library, and the family table reads it so: the php-app row names the demo page and nothing
# else, and the composer-type row is empty, which is what keeps this a php-library.
demo="$(mktemp -d)"; fixtures+=("$demo")
mkdir -p "$demo/src" "$demo/tests" "$demo/public"
printf '{"name":"x/y"}\n' > "$demo/composer.json"
printf '<?php\n'          > "$demo/public/index.php"
( cd "$demo" && git init -q . )
out="$(cd "$demo" && bash "$survey")"
want php-app 'public/index.php' 'typeless library'
rest="$(row php-app | sed 's#public/index.php##; s/[[:space:]]//g')"
[ -z "$rest" ] || note "typeless library: php-app row must name only the demo page, got '$(row php-app)'"
[ -z "$(row composer-type)" ] || note "typeless library: composer-type row must be empty, got '$(row composer-type)'"

# A directory that is not a repository at all.
bare="$(mktemp -d)"; fixtures+=("$bare")
out="$(cd "$bare" && bash "$survey" 2>/dev/null)" || note 'a non-repository directory made the survey exit non-zero'
want root         'not a git repository' 'bare directory'
want base-branch  'unknown'              'bare directory'
want profile      'missing'              'bare directory'

# A Moodle-shaped fixture.
mood="$(mktemp -d)"; fixtures+=("$mood")
mkdir -p "$mood/db" "$mood/lang/en" "$mood/classes"
printf '<?php $plugin->component = "local_x"; $plugin->version = 2026010100;\n' > "$mood/version.php"
printf '<?xml version="1.0"?>\n'                                                > "$mood/db/install.xml"
( cd "$mood" && git init -q . )
out="$(cd "$mood" && bash "$survey")"
want moodle    'plugin'      'moodle plugin'
want manifests 'version.php' 'moodle plugin'
want database-markers 'db/install.xml' 'moodle plugin'

# A Laravel-shaped application: the template's scope is wider than the in-house layout, and
# the php-app row has to name the entry points that show it.
lara="$(mktemp -d)"; fixtures+=("$lara")
mkdir -p "$lara/app/Http" "$lara/routes" "$lara/public"
printf '{"name":"x/app","type":"project"}\n' > "$lara/composer.json"
printf '#!/usr/bin/env php\n<?php\n'          > "$lara/artisan"
printf '<?php\n'                              > "$lara/public/index.php"
( cd "$lara" && git init -q . )
out="$(cd "$lara" && bash "$survey")"
want php-app       'artisan'          'laravel app'
want php-app       'public/index.php' 'laravel app'
want composer-type 'project'          'laravel app'
want entry-points  'artisan'          'laravel app'
want moodle        'no'               'laravel app'

# A Symfony-shaped application: src/ and tests/ like a library, so only the entry point and the
# table's order keep it out of php-library.
sym="$(mktemp -d)"; fixtures+=("$sym")
mkdir -p "$sym/bin" "$sym/src" "$sym/tests" "$sym/config" "$sym/public"
printf '{"name":"x/app","type":"project"}\n' > "$sym/composer.json"
printf '#!/usr/bin/env php\n<?php\n'          > "$sym/bin/console"
printf '<?php\n'                              > "$sym/public/index.php"
( cd "$sym" && git init -q . )
out="$(cd "$sym" && bash "$survey")"
want php-app        'bin/console' 'symfony app'
want entry-points   'bin/console' 'symfony app'
want library-layout 'src'         'symfony app'

# A command that hangs must not hang the skill this runs before. The fake docker
# here sleeps for 30s; the survey has to give up on it and finish anyway — and on
# a machine with no timeout tool, which is the ordinary macOS case.
slow="$(mktemp -d)"; fixtures+=("$slow")
printf '#!/bin/sh\nsleep 30\n' > "$slow/docker"; chmod +x "$slow/docker"
started="$(date +%s)"
out="$(cd "$bare" && PATH="$slow:$PATH" bash "$survey" 2>/dev/null)"
elapsed="$(( $(date +%s) - started ))"
# 25, not 15: the assertion is that the survey gave up rather than waiting out
# the 30s sleep, and a shared CI runner is slower than the 7-8s this takes on a
# developer's machine. A bound with no slack is a test that fails for the weather.
[ "$elapsed" -lt 25 ] || note "a hanging docker held the survey for ${elapsed}s; it must give up"
want docker 'not answering' 'hanging docker'

if [ "$fails" -eq 0 ]; then
  printf 'survey: every row follows its fixture\n'
else
  printf 'survey: %s row(s) wrong\n' "$fails" >&2
fi
exit $((fails > 0))
