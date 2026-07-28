---
name: review
description: Review your own changes before you push or open a pull request — a severity-rated list of what to fix, checked against the repository's own conventions, a lint pass over the changed files, its tests, and the failure modes that green tests miss. Ends by naming the next step. Review-only; never edits, commits or pushes.
argument-hint: "[branch] [--target <base>] [--deep] [--report]"
user-invocable: true
---

# /gku:review — check your own work before anyone else sees it

Run this when you think you are done. It reads what you changed and tells you what a careful
reviewer would say, so you fix it before a bot or a colleague finds it.

Review-only. It never edits your code, never commits, never pushes, never posts anything.

## Arguments

- `branch` — branch to review. Defaults to the current one.
- `--target <base>` — what to compare against. Defaults to the profile's base branch.
- `--deep` — allow one sub-agent to cross-check callers of changed code. Costs more; use it
  for changes that touch shared code.
- `--report` — also write `REVIEW.md`. By default the review stays in the conversation.

## Step 1 — Work out what changed

Read `.claude/repo-profile.json` (see `reference/repo-profile.md` in this plugin — detect and
cache it if missing).

```bash
git diff --stat <base>...HEAD
git diff --name-status <base>...HEAD
```

Include uncommitted work too (`git status --porcelain`) — reviewing only committed changes
misses the half you were about to commit.

Stop early when there is nothing to do:
- on the base branch itself → "You are on `<base>` — switch to your branch first."
- empty diff → "No changes against `<base>`."

## Step 2 — Decide what to read

Do not read everything. Rank by risk and read down the list until the budget is spent:

1. anything writing to the database, handling money or grades, changing schema, touching
   authentication or permissions, or building a file users download — **read fully, plus the
   surrounding unchanged code**, because failures live in the seam between new code and what
   it calls;
2. modifications to code that already existed — read fully;
3. new loops, searches, aggregations, and anything parsing external input — read fully;
4. new self-contained files with straightforward logic — the diff is enough;
5. tests — read enough to judge what they actually prove;
6. markdown, JSON, lock files, translations — diff only.

**Cap: five files read in full.** If more than five qualify, read the top five, and say in the
review which files you judged from the diff alone. An honest limit beats a silent one.

Skip `vendor/`, `node_modules/`, build output, and anything generated.

## Step 3 — Review against this repository

Open the profile's `standardsDoc` and apply *its* rules. There is no built-in style guide
here on purpose — the repository's own conventions win, including inconsistent ones. When a
file around you does something a particular way, matching it is correct.

Assign every finding one of three severities:

- **BLOCKER** — do not push this. A secret or credential committed; a change that silently
  loses or corrupts data; a mass write with no bounded scope; a batch script with no dry-run;
  a data-fix script that duplicates on a second run; a removed or renamed function still
  called elsewhere; user input reaching SQL, HTML or a spreadsheet cell unescaped; broken
  authorisation; a Moodle `classes/`, `db/`, cache or task change with **no `version.php`
  bump** (the live site will not see it).
- **WARNING** — fix before asking for review. New logic with no test; the same block copied a
  third time; an error path nobody handles; a value that can be null and is not checked; a
  loop that can run forever on unexpected data; a comment explaining *what* instead of *why*.
- **NIT** — optional. Naming, ordering, a clearer way to say the same thing.

**Back every BLOCKER and WARNING with the line that proves it.** If you cannot quote the
offending code, drop it one severity and mark it `[unverified]`. Nits can be looser — they
are cheap to dismiss. Overall, lean toward mentioning things: a missed bug costs more than a
nit somebody waves away. The high bar is on the *label*, not on whether you speak up.

## Step 4 — The tests pass. Do they mean anything?

Green tests hide bugs when they are hollow. For every test in the diff, and every production
change that should have had one:

- **No assertion, or a trivial one** (`assertTrue(true)`) → WARNING.
- **Error paths untested** — the diff adds a throw, a guard, or an error return, and nothing
  asserts that failure → WARNING.
- **Edges untested** — new inputs with no test for null, empty, zero, one, or duplicate
  values. On code touching grades, money or records → WARNING; otherwise NIT.
- **Non-deterministic** — real clocks, unseeded randomness, `sleep()` → WARNING. Inject a
  clock, fix a seed, wait on a condition.
- **Leaks state** — mutates globals, environment or shared fixtures without restoring them
  → WARNING; it will poison whatever runs next.
- **Copy-pasted three times** with only literals differing → WARNING; use a data provider or
  parametrised test.
- **Mocks the thing under test** — the code writes raw SQL or walks a data structure, and the
  only tests mock the database away → WARNING. Those tests cannot catch a wrong query or an
  infinite loop.
- **The repository has no tests at all** — say so once, plainly, and suggest the first one
  worth writing. Do not file a warning per file, and never report this as "tests pass".

## Step 4b — Lint the changed files

If the profile has a `lint` command, run it over the changed files, through `exec.prefix`. It is
read-only, it costs seconds, and it is the one mechanical check this skill can make.

This matters most in exactly the repositories that need it most: where there are no tests and no
working CI, nothing else will catch a syntax error before it reaches a live site. A parse error
found here costs a minute; found in production it costs a white page.

- A lint failure is a **BLOCKER**, quoted verbatim. It is not an opinion.
- **Mind the version.** A linter running a newer language version than the project targets will
  happily accept syntax the target rejects — a PHP 8 parser on a project declaring `>=7.4` proves
  only that PHP 8 can read it. When the profile records that mismatch, say so alongside the
  result, and check the diff for constructs newer than the target allows.
- No `lint` command, or `exec` fell back to a host without the toolchain → skip it and say the
  review is unlinted. Never report a lint that did not run.

## Step 5 — Cross-check (only with `--deep`)

One sub-agent, on a small fast model, doing mechanical lookup only: for each function, class
or method the diff renamed, moved or removed, find everything that still refers to the old
name. Anything it finds is a BLOCKER.

Without `--deep`, do this yourself with `grep` for the *renamed and removed* symbols only —
that is the case where a missed caller breaks the site — and skip the rest.

## Step 6 — Say it

Write the review **in the conversation**, not to a file. Lead with the verdict:

> **Ready to push** — or — **2 blockers first** — or — **Ready, with 3 warnings worth a look**

Then, per finding, one bullet: absolute `path:line`, one sentence on the problem, one
sentence on the fix, and the line of evidence. Group by severity, blockers first. Collapse
nits into a single short list.

Close with one line naming what you checked and did not find problems in — conventions, lint,
tests, data safety, wiring — so a clean review reads as *covered*, not *skipped*. Name any file
you judged from the diff alone, and say so if the lint step was skipped.

**Then name the next step**, on its own line. A review that ends in a list leaves the developer
to work out what to do with it, which is a step they should not have to take:

- **blockers or warnings** → `/gku:fix` applies them, one commit each, re-checking every finding
  against the code first. `/gku:fix --nits` takes the nits too.
- **nits only, or clean** → `/gku:pr` opens the pull request; `/gku:verify` first if the change
  needs proving rather than re-reading.

Suggest it; do not run it. This skill does not edit, and the developer decides whether a finding
is worth acting on.

Keep it under ~25 lines when clean, ~40 with findings. It is a message to a colleague.

Write `REVIEW.md` at the repository root **only** with `--report`, or when there is at least
one blocker. Print its absolute path.

## Rules

- **Never edit, commit or push.** You list; the developer decides, and `/gku:fix` applies.
- **Absolute paths** everywhere, so they are clickable in an editor.
- **Never suggest `--no-verify`, `--force`, or `git push --force`.** If a hook fails, the fix
  is the code, not the flag.
- **Write the review in English or Ukrainian** — match the language the developer is using.
  Quote code and comments in their original language, whatever that is.
- **No diff dumps.** One sentence per finding.

## Edge cases

- **Only lock files changed** → review the dependency delta; a major version jump is a
  WARNING, transitive-only changes are informational.
- **Schema changes** (`db/install.xml`, `db/upgrade.php`, migrations, `schema.sql`) → extra
  scrutiny: a dropped column or table, a new `NOT NULL` with no backfill, or a removed index
  with no replacement is a BLOCKER. For Moodle, the `version.php` bump is mandatory.
- **Generated or built files in the diff** (`amd/build/`, compiled assets) → note whether they
  match their sources; do not review them line by line.
- **Fixtures or seed data** → real names, real emails, real student records are a BLOCKER.
  Test data should be obviously fake.
- **Very large diff** → still review, risk-ranked, and say plainly how much you covered.
  Suggest splitting only when the bulk is modifications to existing code; a large pile of new
  self-contained files with tests is fine.
