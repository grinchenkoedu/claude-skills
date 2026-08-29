---
name: implement
description: Build a task step by step in the current session — from a plan file, a markdown brief, or a sentence. Works through ordered steps, ticking each one off in the task file as it lands, so an interrupted run resumes exactly where it stopped instead of starting over.
argument-hint: "<path/to/task.md> | <what to build> [--continue] [--step <n>]"
user-invocable: true
---

# /gku:implement — build it, one step at a time

Takes a plan (or a brief, or a sentence) and builds it here, in this conversation, in order.

It does **not** spawn a fleet of agents. Work happens sequentially in one working tree, which
is both cheaper and easier to follow — you can watch every edit and stop at any point.

**Progress is written into the task file as it goes.** If the session ends — you close it, or
you hit a usage limit — `/gku:implement <same file> --continue` picks up at the first unfinished
step. Nothing is rebuilt.

## Arguments

- **A plan or brief** — `/gku:implement .tasks/individual-plan-export.md`. Preferred: a file from
  `/gku:plan` already has criteria and ordered steps.
- **A sentence** — `/gku:implement add a CSV option to the student export`. Plan it inline
  first (step 2).
- **Nothing** — ask what to build. Never fall back to a leftover file; building the wrong task
  is worse than asking.
- `--continue` — resume, skipping steps already marked done.
- `--step <n>` — run one step only, then stop.

**Telling a file from a sentence:** strip any surrounding quotes, then check whether what
remains resolves to an existing file. It does → a task file. It does not → a request in prose.
A path that was meant to be a file but does not exist must **stop with "no such file"** — never
fall through to treating it as a sentence and building something invented. That mistake is
expensive here, because this skill writes code.

Quotes are optional; arguments are not shell-parsed. They matter only when a flag follows
prose — `/gku:implement add CSV export --continue` is ambiguous about where the description ends,
`/gku:implement "add CSV export" --continue` is not.

## Step 1 — Set up

Read `.claude/repo-profile.json` (see `reference/repo-profile.md`; detect and cache it if
missing). You need its test, lint and build commands, and its base branch.

Check the working tree:

- **Uncommitted changes you did not make** → stop and ask. Do not build on top of someone
  else's half-finished work.
- **On the base branch** → offer to create a branch. Name it for the work:
  `feature/<slug>` or `fix/<slug>`. Do not commit straight to the base branch.

Read the task file. Echo the goal back in one sentence before touching anything — a wrong task
caught here costs nothing.

**Everything that touches the project's toolchain runs through the profile's `exec.prefix`** —
its container, not your machine. The stored `install`, `lint`, `test`, `build` and `runtime`
commands already include it; anything you compose yourself (a one-off script, a database query,
a single-file lint) must be prefixed too. `git`, `gh`, reading and editing files, and HTTP
requests to a published port stay on the host. If the profile fell back to `exec.kind: host`,
say so when you report test results — you tested against your machine's versions, not the
project's.

## Step 2 — Make sure there is a plan

If the input already has acceptance criteria and ordered steps, use them as they are.

If it is a sentence or a loose brief, work out the plan now, inline: find the relevant code,
decide the approach, write down the criteria and the ordered steps. Keep it short — this is
the planning `/gku:plan` would have done, at the scale the task deserves. For anything substantial
or unfamiliar, stop and suggest running `/gku:plan` first; a real plan is worth the separate pass.

Write the plan into the task file so `--continue` has something to resume from.

**Decide the test order now.** Tests come first — before the code they cover — when any of these
holds:

- the developer asked for TDD, or for a failing test first;
- the task file or the brief says so;
- the repository requires it — the profile's `standardsDoc` (`CLAUDE.md` and friends), a
  `CONTRIBUTING.md`, or a visible convention such as every feature landing with its test in the
  same commit.

Otherwise the default order below stands: build, then cover. Say in one line which order you are
using and why, and write it into the task file above the steps so `--continue` finds it:

```markdown
Test order: test-first — required by CLAUDE.md
```

## Step 3 — Build, step by step

**When the order is test-first**, each step starts with its test: write the test for what the
step must do and run it — it has to fail, and fail for the right reason. A test that passes
against code you have not written yet is testing nothing; find out why before continuing. Then
make it pass with the smallest change that does. The step is not done until its test is green,
and step 4 is left only filling the gaps the steps did not reach.

For each step, in order:

1. **Read** the files it touches, and enough around them to not break something.
2. **Make the change**, following the conventions in the profile's `standardsDoc`. Match the
   file you are editing — its naming, its structure, its comment style. Consistency with the
   neighbours beats consistency with a style guide.
3. **Check it immediately** — lint the changed files if the profile has a lint command; run the
   scoped test if one covers this. Finding a mistake now is far cheaper than finding it after
   four more steps.
4. **Mark the step done in the task file**, with one line on what actually landed:

   ```markdown
   - [x] Add the CSV generator — `classes/export/generator/CsvExporter.php` (new)
   ```

5. **Commit** when the step is a coherent unit of work. One commit per step is the default.

Then say, in one line, what landed and what is next. Do not go quiet for six steps.

**Stay inside the task.** Something unrelated and broken that you notice along the way gets
mentioned at the end, not fixed silently. Scope creep in an implementation is how a reviewable
change becomes an unreviewable one.

## Step 4 — Write the tests

If you worked test-first, most of this already exists — walk the list below against what the
steps produced and add what is missing, particularly the error paths and edges that a
step-by-step build tends to skip.

Otherwise, now that the steps are done, cover what you built:

- The main path, asserted properly — not just that it runs.
- **The error paths**, which are the ones that get skipped: bad input, missing record, failed
  write, empty result.
- **The edges**: null, empty, zero, one, duplicates.

Follow the project's existing test conventions — copy the shape of a neighbouring test file.

If the repository has no tests and no test command, say so plainly and write the first one
anyway if the profile shows a usable framework. Do not invent a test harness that does not
exist; note it as something worth setting up.

## Step 5 — Prove it works

Run the profile's test command. Wrap it with the profile's `timeoutTool` where there is one —
**a hang is a failure**, not a reason to wait. When there is no timeout tool available, say so
rather than dropping the timeout silently.

Quote the actual result line as evidence. Not "tests pass" — the line the runner printed.

If something fails, fix it and re-run, **up to three rounds**. After three, stop and report
what is still failing and what you think it is. Do not keep grinding; a fourth attempt on a
tired premise rarely lands, and it is the developer's call whether to keep going.

Then check the change actually does something, using the runtime surface from the profile —
run the command, load the page, call the function. A green test suite for code that was never
executed is not evidence. For a `hosted` runtime (a Moodle plugin and similar), say clearly
that runtime checking needs the host application and stop at lint plus tests. Or hand it to
`/gku:verify`, which does this properly.

## Step 6 — Finish

Handle the things that break a change on the live site but not on your machine:

- **Moodle plugins** — bump `$plugin->version` in `version.php` if you added or moved anything
  under `classes/`, or changed `db/` schema, caches or tasks. Without it the site will not see
  your code.
- **Front-end sources** — run the profile's build command if you touched them.
- **Dependencies** — commit the lock file alongside the manifest.

Then, in chat:

- what was built, in two or three lines;
- the acceptance criteria, ticked or explicitly not met;
- files changed, tests added, the quoted test result;
- anything you noticed but deliberately left alone;
- the next command: `/gku:review` before pushing — then `/gku:fix` for what it finds, and
  `/gku:pr` to open the pull request.

Do not report success when tests are failing or a criterion is unmet. Say exactly what stands.

## Rules

- **Local only.** Never push, never open a pull request, never touch a live system. Pushing is
  a decision a person makes, after `/gku:review` — and `/gku:pr` is where it happens.
- **Sequential. No agent fleets, no background workflows.** One working tree, in order.
- **The task file is the progress log.** Update it as each step lands, so an interrupted run
  resumes instead of restarting.
- **Data-safety rules are not optional** — see `reference/repo-profile.md`. Anything writing in
  bulk needs dry-run by default, safe re-runs, and bounded scope with an expected row count.
- **Never `--no-verify`, `--force`, or `--amend`.** A failing hook means fix the code.
- **Never weaken or delete an existing test to get to green.** If a test now fails and it is
  right to change it, say so explicitly and explain why.
- **Identifiers and commit messages in English**; commit bodies may be English or Ukrainian.
  User-facing strings follow whatever the file already does — a page written in Ukrainian stays
  Ukrainian.

## Edge cases

- **A step turns out to be wrong** — stop, say why, propose the correction, and wait. Do not
  quietly plan something different from what was approved.
- **A step is already done** (someone got there first) — mark it done, note it, move on.
- **The task needs a decision you cannot make** — build everything that does not depend on it,
  then ask one specific question with the options.
- **Usage limit interrupts you mid-run** — the task file already has the ticked steps.
  `/gku:implement <file> --continue` resumes from the first unticked one.
- **The task turns out to be much larger than described** — say so early, propose splitting it,
  and let the developer decide before you build half of it.
