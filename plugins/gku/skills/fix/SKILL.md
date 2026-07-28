---
name: fix
description: Apply the fixes a review asked for — from findings still in this conversation, from a REVIEW.md, or from a sentence describing what is wrong. Re-checks every finding against the current code before touching it, then lands the smallest change per finding and re-runs the tests. Blockers and warnings by default; nits only when you ask.
argument-hint: "[<what to fix> | <path/to/review.md>] [--nits] [--blockers-only] [--dry-run]"
user-invocable: true
---

# /gku:fix — apply what the review found

`/gku:review` tells you what is wrong and stops there, on purpose. This is the other half: it
applies the fixes, smallest change first, one commit per finding, and re-runs the tests.

It also works from cold. Open a new session, type `/gku:fix` with a sentence or a review file,
and it has everything it needs — the findings do not have to be in the conversation.

It writes code. It **does not push and does not open a pull request** — that is `/gku:pr`.

**It never fixes blindly.** A finding is a claim about code, and code moves. Every finding is
re-checked against what is actually there before anything is edited, including findings this
same session produced a minute ago.

## Arguments

- **nothing** — fix the findings from a `/gku:review` earlier in this conversation. If there
  are none, run the review analysis inline first (step 2) and fix what it finds.
- **A sentence** — `/gku:fix the export blows up when a department has no head`. Fixes that one
  thing, nothing else.
- **A file** — `/gku:fix REVIEW.md`, or any markdown holding a list of findings.
- `--nits` — apply nits too. Off by default: nits are matters of taste and they bury the real
  changes in a diff somebody has to read.
- `--blockers-only` — apply blockers, list everything else.
- `--dry-run` — say what would change, per finding, and change nothing.

**Telling a file from a sentence:** strip any surrounding quotes, then check whether what
remains resolves to an existing file. It does → a findings file. It does not → a request in
prose. A path that was meant to be a file but does not exist must **stop with "no such file"** —
never fall through to treating it as a sentence and fixing something invented.

## Step 1 — Set up, and note the state of the tree

Read `.claude/repo-profile.json` (see `reference/repo-profile.md` in this plugin — detect and
cache it if missing). You need its lint, test and scoped-test commands.

**Everything that touches the project's toolchain runs through the profile's `exec.prefix`** —
its container, not your machine. A single-file lint composed on the fly needs the prefix just as
much as the stored test command does. `git`, `gh` and file edits stay on the host.

Then record `git status --porcelain` **before touching anything**, because it decides how fixes
get committed:

- **Clean tree** → one commit per finding. That is what makes any single fix revertible.
- **Dirty, but not in the files a fix touches** → still one commit per finding, staging only
  that finding's paths. Leave the unrelated work alone and untouched.
- **Dirty in the files a fix touches** → the change under review is not committed yet, so a fix
  cannot be separated from it. **Apply the edits and commit nothing.** Say so in the report:
  the fixes are sitting in the working tree alongside work that was already there.

On the base branch, offer to create a branch first, exactly as `/gku:implement` does. Do not
commit to the base branch.

## Step 2 — Get the findings

In precedence order, first match wins:

1. **A sentence** — that is the whole list: one finding, treated as a blocker.
2. **A file** — read it and take its findings. Severities may be missing or written differently;
   map them onto BLOCKER / WARNING / NIT and say how you mapped anything ambiguous.
3. **A `/gku:review` earlier in this conversation** — use those findings as they stand.
4. **Nothing** — run `/gku:review` steps 1 to 5 inline, then fix what they find. Same procedure,
   same severities, same five-file read cap. Report the review briefly before fixing, so you are
   not editing against a list nobody saw.

Nothing to fix at all → say so in two lines and stop. No report, no preamble.

## Step 3 — Re-check every finding before touching it

Findings go stale: the file moved, someone already fixed it, the quoted line is gone, or the
reviewer was wrong. For each finding, in severity order:

1. **Locate the code it names.** Path plus line, or the symbol if the line has drifted.
2. **Confirm the problem is still there**, and quote the line that proves it. This is fast for a
   finding from this session — the evidence line is already written down, so you are only
   confirming it still matches.
3. **Decide, exactly one of:**
   - **stands** — fix it.
   - **already resolved** — the code no longer does what the finding says. No edit, say so.
   - **does not hold** — the claim is wrong about this codebase: a guard the review missed, a
     convention the repository deliberately follows, a test that already covers it. **No edit.**
     Give the file and line that answers it.
   - **needs a decision** — a trade-off that is not yours to make, or two findings that
     contradict each other. No edit yet.
4. **Ask about every "needs a decision" at once**, after checking all of them — one batched
   question, not an interruption per finding.

With `--dry-run`, stop here and report the verdicts.

**A finding you wrote yourself is still a claim.** Re-checking your own review is not
box-ticking: the most expensive mistake this skill can make is applying a fix for a problem that
is not there, because that lands a real change in exchange for nothing.

## Step 4 — Fix, one finding at a time

Blockers first, then warnings, then nits if `--nits` was passed. For each finding that stands:

1. **Read** the file and enough around it to not break something else.
2. **Apply the smallest change that resolves the finding.** Do not refactor nearby code, do not
   tidy the file, do not fix a second finding while you are in there. A fix that grows into a
   rewrite is no longer reviewable against the finding that prompted it.
3. **Check it immediately** — lint the changed file if the profile has a lint command, and run
   the scoped test if one covers it. A failure here means the fix is wrong; fix the fix before
   moving on.
4. **Commit** (when step 1 said to), staging only that finding's paths:

   ```
   Fix: <the finding, in one line>
   ```

5. Say in one line what changed. Do not go quiet for eight findings.

**If a commit hook fails, that finding is skipped and reported as skipped.** Never pass
`--no-verify`. The hook is not the obstacle; the code is.

**If a fix turns out to need a redesign** — a new abstraction, a schema change nobody agreed to,
edits across a dozen files — stop on that finding, say why, and suggest `/gku:plan`. Do not build
it here. Carry on with the rest of the list.

## Step 5 — Prove you did not break anything

Run the profile's test command, wrapped in its `timeoutTool` where there is one. **A hang is a
failure.** When there is no timeout tool, say so rather than dropping the bound silently.

Quote the runner's actual result line as evidence. Not "tests pass" — the line it printed.

Something fails, fix and re-run, **up to three rounds**. After three, stop and report what is
still failing and what you think it is.

Then handle what breaks on a live site but not on your machine:

- **Moodle plugins** — bump `$plugin->version` in `version.php` if a fix added or moved anything
  under `classes/`, or changed `db/` schema, caches or tasks.
- **Front-end sources** — run the profile's build command if a fix touched them.

## Step 6 — Report, and name the next step

In chat, one row per finding: severity, `path:line`, and what happened — **fixed** with its
commit sha, **already resolved**, **does not hold** with the evidence, **skipped** with the
cause, or **awaiting your decision**.

Then, in order:

- the quoted test result;
- nits found but not applied, as a short list, with the one line that takes them:
  `run /gku:fix --nits to take them too`;
- if nothing was committed because the tree was already dirty, say that plainly — the fixes are
  in the working tree, mixed with what was there before;
- **the next step**: `/gku:review` again when blockers were fixed and the change is worth a
  second look, `/gku:verify` when the fix needs proving rather than re-reading, `/gku:pr` when it
  is ready to go out.

**Do not re-run the review yourself.** Fix, review, fix, review is a loop that spends a plan's
worth of usage on diminishing returns. Name the next command and let the developer choose it.

## Rules

- **Never push, never open or update a pull request.** That is `/gku:pr`, and it is a decision a
  person makes.
- **Re-check before you edit.** Always, including your own findings.
- **The smallest change that resolves the finding.** No drive-by refactors, no tidying.
- **One finding, one commit** — when the tree was clean enough to allow it.
- **Nits are opt-in.**
- **Never `--no-verify`, `--force`, or `--amend`.**
- **Never weaken or delete an existing test to get to green.** If a test now fails and changing
  it is right, say so explicitly and explain why.
- **Absolute paths** everywhere, so they are clickable in an editor.
- **Data-safety rules are not optional** — see `reference/repo-profile.md`. A fix to code that
  writes in bulk still needs dry-run by default, safe re-runs and bounded scope.
- **English or Ukrainian, matching the developer.** Identifiers and commit messages in English;
  user-facing strings follow whatever the file already does.

## Edge cases

- **Every finding turns out not to hold** — a legitimate outcome. Change nothing, say so, and
  give the evidence for each. That is a better result than a diff.
- **The findings file is from an old branch** — most will be stale. Say how many still applied
  rather than fixing against a diff that no longer exists.
- **A finding points at code this branch did not change** — out of scope. List it and suggest a
  separate change; do not widen the diff under review.
- **A fix would need a schema change or a version bump** — do it, and say so prominently.
- **Two findings in the same file** — still two commits. Same file is not the same finding.
- **The sentence describes a feature, not a fix** — say so and hand it to `/gku:implement`, or to
  `/gku:plan` if it is substantial. This skill corrects; it does not build.
- **Uncommitted work that is not yours** — the tree already had changes you cannot account for.
  Say what they are and ask before editing those files; fixes elsewhere can proceed.
- **A usage limit interrupts the run** — the commits already made are the progress log. Say which
  findings are still outstanding so the next run can start from them.
