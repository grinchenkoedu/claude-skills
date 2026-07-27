# Repo profile — shared by every skill in this toolkit

Every skill needs the same handful of facts about the repository: how to lint it, how to
test it, how to run it, and what the base branch is called. Detecting that from scratch on
every invocation is the single most wasteful thing these skills could do — so it is detected
**once** and cached.

## The cache

`.claude/repo-profile.json` at the repository root.

**Always read the cache first.** Only run detection when the file is missing, or when the
user passes `--reprofile`, or when a command in it demonstrably no longer works (e.g. the
test command errors with "not found"). After detection, write the file.

Add `.claude/repo-profile.json` to `.gitignore` if it is not already covered — it describes
one developer's machine, not the project.

```json
{
  "family": "php-app | moodle-plugin | php-library | python-app | node | other",
  "language": "PHP 7.4",
  "baseBranch": "master",
  "standardsDoc": "AGENTS.md",
  "install": "make install",
  "lint": "docker run --rm -v \"$(pwd)\":/app -w /app composer:lts php -l {file}",
  "test": "make test",
  "testScoped": "./application/lib/vendor/bin/phpunit --filter {name}",
  "build": "npm run build",
  "runtime": { "kind": "cli", "how": "./run <command>" },
  "container": "docker compose exec app",
  "hasDatabase": true,
  "timeoutTool": "gtimeout",
  "notes": "No local php binary — everything goes through the composer:lts image."
}
```

Any field that does not apply is `null`. A `null` is a real answer and skills must respect
it — a repository with no test command does not get a made-up one.

## Detection, in order

Stop as soon as the family is clear. This should be a handful of file checks, not an audit.

1. **Base branch** — `git symbolic-ref refs/remotes/origin/HEAD` (strip `refs/remotes/origin/`).
   Falls back to whichever of `master` / `main` exists. Do not assume.
2. **Standards doc** — first of `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `README.md` that
   exists. Skills read *this* file for conventions; there is no hardcoded rules file.
3. **Family**, by marker file:

| Marker | Family | What it means |
|---|---|---|
| `version.php` with `$plugin->component` + `db/`, `lang/` | `moodle-plugin` | Code cannot run standalone; it needs a Moodle install around it |
| `composer.json` **and** `application/core/` + `run` | `php-app` | In-house MVC app; `./run` is the CLI entry point |
| `composer.json` with `type: library` / only `src/` + `tests/` | `php-library` | Importable package, tests are the whole runtime surface |
| `requirements.txt` / `pyproject.toml` | `python-app` | |
| `package.json` with no PHP | `node` | |
| none of the above | `other` | Say so plainly; skills degrade rather than guess |

4. **Install / test / build** — read them out of the repo instead of inventing them:
   - a `Makefile` — its targets are the intended interface, prefer them over raw commands;
   - `composer.json` `scripts`, `package.json` `scripts`;
   - `phpunit.xml` / `phpunit.xml.dist` → PHPUnit is present; the binary is usually
     `vendor/bin/phpunit`, but check `composer.json`'s `config.vendor-dir` — it is not always
     `vendor/`;
   - `pytest.ini` / `tests/conftest.py` → `pytest`;
   - `.github/workflows/*.yml` — **the most reliable source.** Whatever CI runs is the real
     test command. Read it before guessing.
5. **Runtime surface** — what can actually be driven to prove a change works:
   - `cli` — a `run` / `bin/*` / `cli/*.php` entry point, or `python main.py`;
   - `http` — a `docker-compose.yml` publishing a port, or a Flask/framework entry point;
   - `library` — importable API only, exercised through tests;
   - `hosted` — a Moodle plugin or similar, which needs a host application. Record this
     honestly: it means runtime verification is limited to lint plus whatever the host's own
     CLI offers, and skills must say so rather than pretend.
6. **Container** — if `docker-compose.yml` exists, the prefix that runs a command inside the
   app service. Check whether it is actually running (`docker compose ps`) before relying on
   it; if it is not, the profile still records it but skills fall back to the host.
7. **`timeoutTool`** — `timeout`, else `gtimeout` (macOS with coreutils), else `null`. When
   `null`, skills must not silently drop the timeout; they run the command and say that a hang
   cannot be bounded automatically.
8. **`hasDatabase`** — a `docker-compose.yml` database service, a `schema.sql`, `db/install.xml`,
   or migrations. Gates the data-safety rules below.

## Family notes worth carrying

- **`moodle-plugin`** — the repository root *is* the plugin root. Entry-point pages
  `require_once` the host's `config.php` from three levels up. Classes under `classes/` are
  autoloaded by namespace, and Moodle **caches the class map**: adding or moving a file under
  `classes/`, or changing `db/` schema, caches or tasks, requires bumping `$plugin->version`
  in `version.php` or the live site will not see it. This is the single most common way a
  correct-looking change fails in production — treat a missing bump as a blocker.
- **`php-app`** — `application/` holds `controllers/`, `models/`, `views/`, `commands/`,
  `core/`. `./run` dispatches CLI commands. Several of these repositories have **no tests at
  all**; skills must not report "tests pass" when what happened is "there are no tests".
- **`php-library`** — CI already runs the suite on every push. The tests are the contract.

## Data-safety rules

Apply when `hasDatabase` is true. These exist because student records, grades, individual
plans and registry rows are records-of-record: a wrong `WHERE` clause is not a bug you fix
forward, it is data you have lost.

- A batch script that writes must support **dry-run, defaulting to dry-run**. Applying is an
  explicit flag.
- A data-fix script must be **safe to run twice**: the second run is a no-op, not a duplicate.
- A mass update needs **bounded scope** (an explicit id set or range) and an
  **expected-row-count assertion** that aborts when reality disagrees.
- Deletions and overwrites of user-supplied content need a stated recovery path before they run.

Each of these missing, in code that writes to the database, is a blocker — not a style note.

## Cost discipline

These skills are built to be run often on a modest plan, so every one of them obeys the same
limits. If you are extending a skill, keep them.

- **No sub-agents by default.** At most one, only behind an explicit `--deep` flag, and pinned
  to a small fast model since its job is mechanical scanning.
- **Never spawn background agent fleets or workflow runs.** A single session does the work.
- **Read the diff, not the repository.** Full-file reads are capped at the five highest-risk
  files; everything else is judged from the diff.
- **Chat first.** A markdown report is written only when there is a blocker, or when the user
  asks with `--report`. Most runs should end in the conversation.
- **Exit early.** Nothing to do means two lines and a stop, not a report explaining that there
  was nothing to do.
