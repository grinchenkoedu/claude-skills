---
name: pr-resolve
description: Work through the review comments on your own pull request — every finding gets a verdict before any code changes (agree, disagree with evidence, or ask you), then fixes land one commit per finding, get pushed, and each thread gets a reply. Never fixes blindly; reviewers and bots are sometimes wrong.
argument-hint: "<pr-number-or-url> [--repo <owner/name>] [--dry-run]"
user-invocable: true
---

# /pr-resolve — act on the comments on your pull request

Someone (usually the automated reviewer, sometimes a colleague) left comments. This works
through all of them in one pass, without touching whatever you currently have checked out.

This is the one skill here that **writes code and pushes**. It only ever works on **your own**
pull request.

**The rule that matters: never fix blindly.** An automated reviewer is tuned to sound
confident and is regularly wrong about whether something is actually a problem *in this
codebase*. Every finding is checked against the code before anything is edited.

## Arguments

- `<pr-number-or-url>` — required. There is no default; this skill changes files, so the
  target must be explicit.
- `--repo <owner/name>` — otherwise taken from `origin`.
- `--dry-run` — analyse and report verdicts, change nothing. Good for a first look.

## Step 1 — Fetch the pull request

```bash
gh pr view <n> --repo <owner/name> --json number,state,headRefName,baseRefName,author,url,headRefOid
```

Refuse if it is not open. Refuse if the author is not you — for someone else's PR, use
`/pr-review` and hand them the findings.

## Step 2 — Collect every finding

```bash
gh api /repos/<owner>/<repo>/pulls/<n>/comments   # inline review comments, with ids
gh api /repos/<owner>/<repo>/pulls/<n>/reviews    # review bodies, including bot summaries
gh api /repos/<owner>/<repo>/issues/<n>/comments  # general discussion
```

Sort each into a bucket:

- **actionable** — names a file or proposes a concrete change, and is not yet resolved.
- **question** — asks something without proposing a change. Gets a reply, not a commit.
- **nit** — marked optional, minor, or non-blocking. Fix only if it is a one-line change;
  otherwise list it and move on.
- **skip** — emoji, "looks good", automated summaries with no specific finding, and anything
  you have already replied to.

Automated reviewers post a summary review plus individual inline comments. The inline
comments carry ids and **can** be replied to; the summary cannot — record your verdict on
those in the final report instead.

## Step 3 — A verdict for every finding, before any edit

For each actionable and nit finding:

1. **Restate the claim** in one sentence — what is said to be wrong, and what would happen if
   that were true?
2. **Check it against the code.** Read the cited location and enough context to judge it: the
   callers, the guard the reviewer may not have noticed, the test that already covers it.
3. **Decide, exactly one of:**
   - **agree** — it holds. Note the smallest fix that resolves it.
   - **disagree** — it does not hold here. It may be a false positive, already handled
     elsewhere, or the suggestion would make things worse. **No code change.** Draft a short,
     respectful reply with the evidence: the file and line that answers it, and one sentence
     of reasoning.
   - **unclear** — genuinely ambiguous, or a design trade-off that is not yours alone to make.
     Do not guess in either direction.
4. **Ask about all the unclear ones at once**, after analysing everything — one batched
   question, not an interruption per comment. Offer: fix as suggested / push back / leave it.

Record the verdict and a one-line reason for each. This trail is what the final report prints
and what the replies quote.

With `--dry-run`, stop here and report.

## Step 4 — A worktree to work in

```bash
git fetch origin <headRefName>
git worktree add ../<repo>-pr-<n> <headRefName>
```

This keeps your current work untouched. If the path exists, ask before reusing it. If the
branch is checked out elsewhere, say so — commits here will not show up there until they pull.

## Step 5 — Fix, one finding per commit

For each **agree** verdict, in order:

1. Read the cited file and its surroundings.
2. Apply **the smallest change that resolves the finding.** Do not refactor nearby code. Do
   not bundle two findings into one commit even when they touch the same file — one commit
   per finding is what makes any of it revertible.
3. Commit, referencing what it addresses:
   `Fix: <one-line description of the finding>`
4. If the repository has a lint or test command in the profile and the change is testable, run
   the scoped version now, **through the profile's `exec.prefix`** — the project's container,
   not your machine, so the check uses the version the project targets. A failure means the fix
   is wrong; fix the fix before continuing.

   Note that a compose service mounts the *primary* checkout, not this worktree. Either use an
   image-based prefix mounting the worktree, or record the fix as unverified — do not run the
   check against the wrong tree and call it passed. `git`, `gh` and file edits stay on the host.

**If a commit hook fails, that finding is skipped and reported as skipped.** Never pass
`--no-verify`. The hook is there for a reason and silencing it is not resolving anything.

## Step 6 — Push

```bash
git push origin <headRefName>
```

Never `--force`, never `--force-with-lease`, never `--amend`. If the remote branch has moved
because someone else pushed, rebase **only your own new commits** from this run onto it, then
re-verify any fix that overlapped their change. If that rebase conflicts, stop and hand it
back — a conflict needs a human.

If the *base* branch has moved and the PR now says it needs a rebase, leave it. That is a
deliberate human decision, not something this skill does.

## Step 7 — Reply to each thread

One reply per inline comment you acted on:

```bash
gh api -X POST /repos/<owner>/<repo>/pulls/<n>/comments/<comment_id>/replies -f body='...'
```

- **agree, fixed** — `Fixed in <sha>: <one sentence on what changed>.`
- **disagree** — the evidence-backed reply from step 3. Do not resolve the thread; the
  reviewer decides whether they accept it.
- **question** — answer it plainly, or say what you need in order to answer.
- **skipped because a hook failed** — say that, and say what failed.

Resolve only threads you actually fixed. Never resolve a thread you pushed back on, and never
resolve someone else's question.

## Step 8 — Report

In chat: a short table of every finding, its verdict, and what happened — fixed with a commit
sha, pushed back with the reason, skipped with the cause, or awaiting your decision. Then the
push result and the PR link.

Finish by offering to remove the worktree. Never remove it without asking.

## Rules

- **Verdict before edit, always.** A fix applied without checking the claim is how a
  confidently-worded false positive becomes a real bug.
- **One finding, one commit.**
- **Never `--no-verify`, `--force`, or `--amend`.**
- **Only your own pull requests.**
- **Never resolve a thread you did not fix.**
- **Push back politely and with evidence.** Cite the file and line that answers the claim.
  Being right is not a reason to be curt — and being confident is not the same as being right,
  so if the evidence is thin, treat it as unclear and ask.

## Edge cases

- **Every finding is a false positive** — that is a legitimate outcome. Push back on all of
  them, push nothing, and say so.
- **A finding points at code the PR did not change** — out of scope. Reply saying so and
  suggest a separate change.
- **Two findings contradict each other** — treat as unclear and ask.
- **A fix would need a schema change or a version bump** — do it, and say so prominently in
  the report; for a Moodle plugin, a `classes/` or `db/` change without a `version.php` bump
  will not take effect on the live site.
- **The PR has no comments yet** — say so and stop.
