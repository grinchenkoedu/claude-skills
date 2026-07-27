---
name: verify
description: Check that a change actually works — run the project's tests, then drive the real thing (the command, the page, the function) and confirm the effect. Reports a clear verdict, and says honestly what could not be checked and why, instead of quietly skipping it.
argument-hint: "[<pr-number> | <branch>] [--tests-only] [--report]"
user-invocable: true
---

# /verify — prove it works

Tests passing and a feature working are different claims. This skill makes both, separately,
and says which one it can actually support.

Run it after `/implement`, before opening a pull request, or against someone's pull request
when you want more than a reading of the diff.

Local only. It never touches a live system and never writes to the pull request.

## Arguments

- **nothing** — verify the current working tree against the base branch.
- **`<pr-number>`** — check out that pull request's head in a worktree and verify it.
- **`<branch>`** — verify that branch.
- `--tests-only` — skip driving the runtime; just run the suite.
- `--report` — write `VERIFY.md`. Otherwise the verdict stays in chat.

## Step 1 — Preflight, and be honest about blockers

Read `.claude/repo-profile.json` (see `reference/repo-profile.md`).

Check, and report all of these together in one block rather than discovering them one at a
time:

- Is there a test command at all? Many repositories here have none.
- Is the execution environment available? For `exec.kind: compose`, is the service up
  (`docker compose ps`)? For `image`, is the Docker daemon running? If Docker is down and the
  profile expects it, that is a `SETUP` blocker — starting it is usually the whole fix.
- Are dependencies installed? (`vendor/`, `node_modules/` as applicable)
- Is there a `timeoutTool`?
- Does the runtime surface need something you do not have — a host application, a credential,
  an external service?

**Everything that exercises the project runs through the profile's `exec.prefix`** — its
container, not your machine. The stored `test`, `lint` and `runtime` commands already carry it;
any probe you compose yourself needs it too. On the host stay: `git`, `gh`, file reading, and
HTTP requests to a published port (those go to `localhost:<port>`, not through `exec`).

This matters most here, because this skill's whole output is a claim about whether something
works. A suite that passed against your machine's runtime instead of the project's has not
verified the project — if `exec.kind` is `host`, the verdict must say which versions were
actually used.

Every blocker gets a **category** and a one-line way out:

| Category | Means | Example |
|---|---|---|
| `SETUP` | environment not ready | container down, dependencies not installed |
| `MISSING` | the project has no such thing | no test command, no tests at all |
| `HOSTED` | needs a host application | a Moodle plugin cannot run standalone |
| `EXTERNAL` | needs something outside this machine | a third-party API with no sandbox |
| `DATA` | no suitable local data, and none can be safely made up | needs a record in a state fixtures do not produce |
| `PRE-EXISTING` | already broken before this change | prove it by running the same check on the base branch |

A `SETUP` blocker you can clear in under a minute: clear it and note that you did. Anything
else: **record it, skip that check, and carry on with the rest.** Only abandon the whole run
when the code itself cannot be obtained.

## Step 2 — Isolate, if verifying a pull request

```bash
git fetch origin pull/<n>/head
git worktree add ../<repo>-verify-<n> <head-sha>
```

**Mind what the execution environment is actually pointed at.** A compose service
(`exec.kind: compose`) mounts the *primary* checkout, not this worktree — so commands run
through it would test the wrong code. Two honest options:

- run the checks from the primary checkout with that commit checked out — record the original
  branch and restore it in step 6, without exception; or
- for `exec.kind: image`, mount the worktree instead (`-v "<worktree>":/app`), which avoids the
  problem entirely and is the better route when the project has a usable image.

Do not run the checks against the wrong tree and report the result as if it meant something.

For the current working tree, none of this applies.

## Step 3 — What needs checking

Build a short list, one row each for:

- every acceptance criterion, if there is a task file or a pull request description;
- every command, page or function the change touches;
- every schema change;
- the failure modes the change makes plausible.

Each row ends up passed, failed, or skipped-with-a-category. **A criterion with no row is a
gap, and the report must say so** — silence is not coverage.

## Step 4 — Run the tests

Run the profile's test command, wrapped in its `timeoutTool`. Prefer the scoped form first
(the tests covering what changed), then widen if it is quick.

- **Quote the runner's actual result line.** "Tests pass" is not evidence; `OK (43 tests, 118
  assertions)` is.
- **A timeout is a failure.** Capture what it was doing when it hung.
- **Something failing that also fails on the base branch is `PRE-EXISTING`** — prove it by
  running the same command on the base branch before blaming this change.
- **No tests in the repository** → `MISSING`. Say it plainly. Never let an absence of tests be
  reported as tests passing.

## Step 5 — Drive the real thing

This is the part that catches what tests do not. Use the runtime surface from the profile:

- **`cli`** — run the command twice: once with bad input (expect a clear error *and* a non-zero
  exit code — check the exit code directly, a pipe hides it), once for real. Check the effect
  afterwards: the row written, the file produced, the output correct.
- **`http`** — request the route. Check the status, then check the effect. If a browser is
  available, click the actual flow; otherwise `curl` it and say in the report that the check
  was request-level, not user-level.
- **`library`** — call the public API directly with ordinary and edge inputs.
- **`hosted`** — a Moodle plugin or similar cannot run without its host. Record `HOSTED`, and
  do what can be done: lint every changed file, confirm `version.php` was bumped when
  `classes/` or `db/` changed, and confirm any new class is where its namespace says it should
  be. Say clearly that behaviour was not verified.

Then the adversarial checks the change makes relevant: what happens when it is run twice, on
an empty result, on a record that is already processed, on unexpected null values. For
anything writing in bulk, verify the data-safety rules hold — run it in dry-run and confirm
nothing changed, run it twice and confirm the second run is a no-op.

Wrap everything in a timeout. Kill anything left running.

## Step 6 — Restore the environment

**Do this even if the run failed or was abandoned halfway.** A half-restored environment is
the worst outcome of all.

- Undo any data you changed, in reverse order.
- If you detached the primary checkout, return it to its original branch.
- Clear caches or rebuild whatever you invalidated.
- Ask before removing a worktree. Never remove one silently.

## Step 7 — Verdict

Lead with one of:

- **Works** — the checks that matter passed, and the change was actually exercised.
- **Works, with notes** — passed, but something is worth knowing.
- **Does not work** — a specific, reproducible failure.
- **Cannot tell** — too much was blocked to make a claim. Say what was blocked and how to
  unblock it.

Then: the check list with evidence per row (the quoted output line, the exit code, the status
code, the row that changed); the failures with how to reproduce them; the skipped rows with
their categories; and anything you changed in the environment and restored.

**"Cannot tell" is a real and useful verdict.** A confident "works" that rests on three
skipped checks is worse than useless — it is misleading.

Write `VERIFY.md` only with `--report` or when the verdict is "does not work".

## Rules

- **Local only.** Never a live system, never production data, never a write to the pull
  request.
- **Reversible by default.** When a check must change local data, record the undo before doing
  it, and apply it in step 6.
- **Evidence or it did not happen.** Every passed row quotes something real.
- **One failure never cancels the rest of the list.**
- **Never report tests as passing when there are no tests.** This is the single most common way
  a verification lies.
