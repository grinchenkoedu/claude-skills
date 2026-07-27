---
name: pr-review
description: Deep review of someone else's pull request in an isolated worktree — hunts the failures that automated review misses (broken error paths, infinite loops, races, blast radius, claim-vs-code drift), deduplicates against the bot's comments, and gives a short verdict in chat. Read-only; never edits, pushes or posts.
argument-hint: "<pr-number-or-url> [--repo <owner/name>] [--deep] [--report]"
user-invocable: true
---

# /pr-review — review someone else's pull request

The last check before a change lands. By the time this runs, an automated reviewer has
usually already commented and CI has usually already passed — so this skill deliberately does
**not** repeat that work. It looks for what those layers structurally cannot see.

Read-only: it never edits, commits, pushes, or posts a comment. You paste what you want to
say yourself.

For your *own* changes before pushing, use `/review` instead.

## What to skip, and what to hunt

**Skip** — formatting, import order, naming preferences, docblock style, and anything the
automated reviewer already commented on. Mention a basic only when it is the visible tip of a
real defect: report the wrong value it produces, not the style rule it breaks.

**Hunt** — the things a diff-shaped reviewer misses:

- **Failure paths** — what happens when the happy path breaks halfway. An exception between
  two writes, a transaction left open, a half-updated record, a retry that duplicates work.
- **Loops that may not end** — walk every new loop, search or cursor against hostile data:
  gaps in ids, empty sets, duplicates, nulls. Mocked tests prove nothing here; check the
  algorithm itself.
- **Races and double-submits** — check-then-act, a form submitted twice, a scheduled task
  overlapping its previous run, a unique constraint that deduplicates the *row* but not the
  *action*.
- **Data safety** — see the data-safety rules in `reference/repo-profile.md`. Unbounded mass
  updates, batch scripts with no dry-run, fix scripts that duplicate when re-run.
- **Blast radius** — who calls the changed code. Renamed methods with stale callers, listeners
  on renamed events, a schema change against a table that already holds real rows.
- **Claim versus code** — does the diff do what its description promises? Look for quietly
  dropped requirements and behaviour changes hidden inside a "refactor".
- **Honest tests** — tests that mock away exactly what changed, assertions weakened until they
  passed, tests deleted or skipped, coverage that exercises the old path.
- **Design smell** — logic at the wrong level (business rules in a page script), copy-paste
  divergence from an existing pattern, dead code left wired up, an abstraction that will force
  the next change to touch five files.

## Step 1 — Fetch it

Repository from `--repo`, else from `git remote get-url origin`.

```bash
gh pr view <n> --repo <owner/name> --json number,title,state,author,headRefName,baseRefName,headRefOid,isCrossRepository,url,body,additions,deletions,changedFiles
```

Note the state. A merged or closed PR is still worth reading — frame the review as
after-the-fact.

Stop with a one-liner if the PR changes no files.

## Step 2 — Isolate it in a worktree

A worktree gives you the whole tree at the PR's commit without disturbing what you are
working on. You need it: the findings above live *outside* the diff, in the code the change
calls and the code that calls it. A diff alone cannot show you those.

```bash
git fetch origin pull/<n>/head          # works for forks too
git worktree add ../<repo>-pr-<n> <headRefOid>   # detached; never a local branch
```

If the path exists already, ask before reusing it. Never overwrite silently.

Work inside the worktree for steps 3–5. Capture the primary repository path first
(`git rev-parse --show-toplevel`) — any report goes there, not into the worktree.

**If the profile's execution environment is a compose service**, it mounts the *primary*
checkout, not this worktree — so anything run through it would exercise the wrong code. That is
fine for a static review; if verifying a finding would need to run code, either mount the
worktree into a one-off container (`exec.kind: image` style) or mark the finding `[unverified]`
rather than guessing.

## Step 3 — Read, risk-ranked

```bash
git diff --stat <baseRefName>...HEAD
git diff --name-status <baseRefName>...HEAD
```

Read in the priority order from `/review` step 2, with the same **cap of five files read in
full** plus the unchanged code immediately around them. Everything else is judged from the
diff, and the review says so.

This is a focused deep read, not an audit. Spend the budget on the risky rows.

## Step 4 — Two severities

- **BLOCKER** — would break something in production or is wrong on a plausible path. Every
  blocker needs a **concrete failure scenario**: the inputs or state that trigger it and what
  goes wrong. If you cannot describe that, it is a smell.
- **SMELL** — will not break tomorrow but will hurt: coupling, wrong level, a race with no
  consequence yet, dishonest tests, dead code, an abstraction fighting the next change.

There is no NIT here. Nits are the bot's job.

## Step 5 — Deduplicate against the bot and the humans

```bash
gh api /repos/<owner>/<repo>/pulls/<n>/reviews
gh api /repos/<owner>/<repo>/pulls/<n>/comments
```

Automated reviewers appear as bot accounts (for example `copilot-pull-request-reviewer[bot]`,
with comments authored by `Copilot`).

- **Drop any finding the bot already made** — the author has been told.
- Where a human raised the same thing, add *(also raised by @name)* — corroborate, do not
  repeat.
- Where a human caught something you missed, say so and credit them.
- **A bot's approval is not evidence of anything.** Automated review is tuned for precision on
  style; it approves changes containing infinite loops and broken permissions. Never let it
  soften your verdict.

With `--deep`, one sub-agent on a small fast model may look up callers of changed symbols.
Otherwise `grep` the worktree yourself for renamed and removed names only.

## Step 6 — Say it, briefly

**The chat message is the deliverable.**

> **Approve** — or — **Approve with notes** — or — **Request changes — 2 blockers**

Then each blocker in two or three sentences: what breaks, when, and the direction of the fix,
with an absolute `path:line`. Smells get one line each. Add a short note on what is done well —
it keeps the review fair. Close with one line on what the earlier layers already covered.

Under ~25 lines for a clean PR, ~40 with findings.

Write `PR_REVIEW_<n>.md` in the **primary** repository only when there is at least one
blocker, or four or more findings, or `--report` was passed. Print its absolute path.

## Step 7 — Offer to clean up

Ask once, with the absolute path:

> Worktree left at `<path>`. Remove it? (`git worktree remove <path>`)

Never remove it without asking.

## Rules

- **Read-only.** No edits, no commits, no pushes, no posted comments. You hand the findings to
  a human.
- **Absolute paths** in every finding, rooted at the worktree, so they open in an editor.
- **Every blocker carries a failure scenario.** No scenario, no blocker.
- **English**, translating anything quoted.
- **No diff dumps.**

## Edge cases

- **Fork PR** — `git fetch origin pull/<n>/head` handles it; do not try `origin/<branch>`.
- **Stacked PR** (base is another feature branch) — review works, but say in the header that
  it is only meaningful once the parent lands.
- **Conflicts with the base** — review anyway, and lead with the fact that it cannot merge
  as-is.
- **Very large PR** — risk-ranked reading already caps the cost. Suggest splitting only when
  modifications to existing code dominate.
- **No tests in the repository at all** — do not file that as a finding on this PR. Mention it
  once as context.
