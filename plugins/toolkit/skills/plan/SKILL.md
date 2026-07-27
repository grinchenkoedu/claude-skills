---
name: plan
description: Turn a request — a sentence you type, or a markdown brief — into a grounded plan you can hand to /implement. Works out what is really being asked (bug, feature, question, data fix), checks it against the actual code and data, and writes an ordered plan with acceptance criteria. Plans only; writes no production code.
argument-hint: "\"<what you want>\" | <path/to/brief.md> [--review] [--deep]"
user-invocable: true
---

# /plan — work out what to build, before building it

Give it a request in plain words, or point it at a markdown brief. It reads the code, checks
its assumptions against real data where it can, and produces a plan concrete enough that
`/implement` can execute it without thinking the problem through again.

It writes **no production code**. The only files it creates are the plan itself and, at most,
one throwaway read-only script used to answer a question about the data.

## Arguments

- **A sentence** — `/plan "the export merges departments that share a name"`
- **A markdown file** — `/plan .tasks/individual-plan-export.md`, for a longer brief that was
  written up in advance. Read the whole file; it is the specification.
- **Nothing** — ask what to plan. Never guess.
- `--review` — a brief that already proposes a solution: judge that proposal instead of
  designing a fresh one (see step 6).
- `--deep` — allow one sub-agent for mechanical code search on a large unfamiliar area.

## Step 1 — Understand the request

Read `.claude/repo-profile.json` (see `reference/repo-profile.md`; detect and cache if
missing). Then classify what is actually being asked — the words people use do not always
match what they need:

| It is really a | Signals | What you owe |
|---|---|---|
| **bug** | "wrong", "broken", "should not", a description of something that happened | the **cause**, proven, then the fix |
| **feature** | "add", "support", "we need to be able to" | a **design**: where it hooks in, what it touches, in what order |
| **question** | "how many", "why does", "is it possible", "can we" | the **answer**, with evidence. Often no code needs to change |
| **data fix** | "these records are wrong", "recalculate", "stuck" | how many rows, why, and a **safe** strategy to correct them |

If the request is too vague to classify, ask **one** question and wait. That is the only point
where this skill blocks. One good question beats a plan built on a guess.

## Step 2 — Find the code

Extract two to four distinctive terms from the request and search for them. Read what you
find — the entry points, the classes involved, the tests that already cover the area.

Also check whether **the work is already done**. An existing command, script or function that
solves this is the best possible outcome: point at it and stop. Look before you design.

Read the profile's `standardsDoc` for the conventions the plan must follow.

With `--deep`, one sub-agent on a small fast model may sweep a large unfamiliar area for
relevant files. Otherwise search yourself — in a repository this size, `grep` is faster than
a sub-agent and costs nothing.

## Step 3 — Check the facts

A cause you have not verified is a guess. Say which one you are stating.

Where a claim rests on data — how many rows, what states exist, whether this actually happens,
what the schema really looks like — check it. Use whatever the profile says this project has:
a database in the local container, a fixture set, a small read-only script.

- **Local data only.** Never point anything at a live production system. If a question can
  only be answered against production, write the read-only script, leave it untracked, and put
  the exact command in the plan for a human to run.
- **Anything generated here reads and never writes.** A script that corrects data is part of
  implementing the fix — designed here, written later, under the data-safety rules.
- **Tag every fact with where it came from** — `[local database]`, `[needs a production run:
  <script>]`, `[from the code]`, `[assumed]`. An untagged number in a plan gets treated as
  true by everyone downstream.

If the project has no database at all, say so and lean on the code.

## Step 4 — Decide the approach

For most requests, reason it through directly: you have read the code and checked the facts,
so pick the approach that fits this codebase and say why.

For a genuinely open design question — several defensible approaches, or a change that will be
hard to reverse — lay out the options in a short table with their trade-offs, recommend one,
and say what would change your mind. **Do not spawn a panel of agents to argue about it.**
Two or three options reasoned about honestly is worth more than a committee, and costs a
fraction as much.

The plan must be concrete: real file paths, real function and class names, an order, and an
explicit list of what **not** to touch.

## Step 5 — Write it

Save to `.tasks/<slug>.md` (create `.tasks/` if needed; add it to `.gitignore` unless the
project deliberately commits briefs). Overwrite an existing plan for the same slug.

```markdown
# <Short title>

**Type:** bug | feature | question | data fix
**Asked:** <the original request, verbatim>

## Summary
<Three bullets at most. The finding, what to do, and the biggest risk.>

## <Cause | Design | Answer | Strategy>
<The actual deliverable. For a bug: what is wrong and why, with evidence.
For a feature: where it hooks in and what it touches. For a question: the answer.>

## Acceptance criteria
- [ ] <checkable, specific — this is what /implement builds against and what /verify checks>

## Steps
1. <ordered, file-level, buildable one at a time>

## How to check it
- `<the exact command from this project that proves it works>`

## Do not touch
- <files, tables or behaviour that must stay as they are, and why>

## Evidence
- **Code:** <path — one line on why it matters>
- **Data:** <fact — [source tag]>
- **Open questions:** <numbered, each answerable>
```

Omit acceptance criteria and steps for a pure question — the answer is the deliverable.

## Step 6 — Judging an existing proposal (`--review`)

When the brief already says how it should be done, do **not** design something different.
Judge what is proposed:

- **Check every load-bearing claim.** Does the named class actually exist and behave as
  described? Is the table shaped the way the brief assumes? A brief resting on a wrong
  assumption is the finding.
- **Is it sufficient?** Does it meet every stated criterion, including the ones easy to skip?
- **Is it more than necessary?** A simpler approach that meets the criteria is a finding too.
- **Does it fit this codebase's conventions?**
- **What happens when it fails?** Partial writes, re-runs, unexpected data.

Then a verdict: **sound** / **sound with changes** / **needs rework** / **cannot judge — need
answers first**, with the reasoning and, for anything below "sound", what to change.

## Step 7 — Hand off

In chat: the absolute path to the plan, the summary verbatim, and — when there is something to
build — the next command:

```
/implement .tasks/<slug>.md
```

The plan was written to be executed without re-deriving it.

## Rules

- **No production code.** Only the plan, and at most one read-only script (untracked, with its
  command written into the plan).
- **Evidence over assertion.** An unverified cause is labelled a hypothesis.
- **Production is read-only, and only by a human.** Local queries are yours to run; anything
  against production goes in the plan as a command for a person.
- **Data-safety rules apply to any strategy you propose** — see `reference/repo-profile.md`.
  A data fix must specify dry-run by default, safe re-runs, and bounded scope with an expected
  row count. Design it here; write it in `/implement`.
- **One clarifying question, maximum**, and only when classification is genuinely blocked.
- **Absolute paths. English. No essays** — a reader of the summary alone should be able to act.

## Edge cases

- **It is already solved** — a short plan pointing at the existing thing. Do not rewrite it.
- **Nothing in this repository matches** — say so; it may belong in another repository. Name
  which, if you can tell.
- **The request spans several repositories** — plan only this one's part and name the rest.
- **A brief contradicts the code** — the code is what runs. Flag the contradiction as the
  first open question rather than planning around it.
- **The change is a one-liner** — say so and skip the ceremony. Not everything needs a plan.
