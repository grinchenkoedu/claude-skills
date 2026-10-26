# /gku:plan --manual — the plan a person builds by hand

Read only when `/gku:plan` was given `--manual`, before its step 6 writes the file. The step
numbers below are `SKILL.md`'s.

`--manual` changes nothing before step 6. Steps 1–5 run exactly as written — the
classification, the code reading, the fact-checking with source tags, the batched question
round — a plan somebody follows by hand is worth only as much as the evidence under it.
What changes is the file that comes out of step 6.

It is written for two readers who are not `/gku:implement`: a developer in a repository where
the code has to be written by a person, and a developer learning this codebase. Both need the
*why* beside the *what*, and neither needs a block to paste.

**Shapes, never paste-ready code.** A step names the file, the symbol, the signature and the
code already in this repository to mirror — and says why it is shaped that way. It does not
carry an implementation to paste in whole. Two reasons: a paste-ready plan is generated code
with one extra hop, which is exactly what a repository that bans generated code is avoiding;
and a learner who pastes has learned nothing. A genuinely non-obvious fragment — a regex, a
query predicate, an escaping call — may appear inside a `Shape:` line as an example, marked as
one.

**Detail aimed at someone who has not read the code.** Each step says where to open the file,
what is already there, what to add, and what the surrounding code expects of it. That is more
prose than an `/gku:implement` step needs, and it is the point of the mode. Still one step, one
commit: if a step cannot be proved on its own, it is two steps.

**Nothing here commits.** Say so at the top of the file and again at the end of every step. A
finished step that was never committed gets tangled into the next one, and the whole recovery
story of this mode is that the last commit is a state to get back to.

**The file is the session's memory.** A manual build spans days, compactions and fresh
sessions, and nothing but this file survives them: it therefore carries the request verbatim,
the questions with their answers, the progress so far, and the prompt to reopen it with.

## The file

Same location and slug rules as step 6. The header marker is what `/gku:implement` and
`/gku:review` read, so it goes in exactly this form:

````markdown
# <Short title>

**Type:** bug | feature | question | data fix
**Language:** <ISO 639-1 code — `reference/language.md`>
**Mode:** manual
**Asked:** <the original request, verbatim>
**Plan file:** <absolute path to this file>

> **You are building this by hand.** Nothing in this file writes code for you and nothing
> commits for you: finish a step, check it, **commit it yourself**, then start the next one.

## Summary
<Three bullets at most. The finding, what to do, and the biggest risk.>

## <Cause | Design | Answer | Strategy>
<As in step 6 — and, for a learner, what the surrounding code does today, so the change has
somewhere to sit.>

## Acceptance criteria
- [ ] <checkable, specific — what you are building against>

## Steps
1. <what the step does, in one line>
   - Create: <paths this step adds>
   - Modify: <path:lines this step changes — name the symbol too>
   - Shape: <the signature and structure to write, and the code here to mirror>
   - Why: <what breaks if it is shaped differently>
   - Prove it: `<the exact command>` — expect <the observable result>
   - Then commit this step yourself.

## How to check it
- `<the exact command from this project that proves the whole thing works>`

## Do not touch
- <files, tables or behaviour that must stay as they are, and why>

## Progress
<Tick a step when its commit exists. This is where a new session finds you.>
- [ ] 1. <step title> — commit:
- [ ] 2. <step title> — commit:

## Q&A
<Every question that shaped this plan, and every one settled later. Newest last.>
- **<date> — <the question>** — <the answer, in the words it was given> `[answered]`

## Resume prompt
<Paste this into a new session after a compaction, or tomorrow.>

```
Read <absolute path to this file> — a manual plan I am building by hand.
Check ## Progress for where I am, then help me with the first unticked step.
Explain and review; do not write the code for me, and do not commit anything.
Append anything we settle to ## Q&A with today's date.
```

## Evidence
- **Code:** <path — one line on why it matters>
- **Data:** <fact — [source tag]>
- **Still open:** <only what nobody here could answer — who can, and what was assumed>
````

`Create:` and `Modify:` stay in the step for the same reason they exist in step 6 —
`/gku:review` greps them for symbols that moved, and it reviews hand-written code exactly as it
reviews built code. `## Q&A` is where the step 5 answers go in this mode; `## Evidence` keeps
the code and data lines.

## Handing it over

The hand-off (step 8) does **not** offer `/gku:implement`: that skill would build what the file
was written for the developer to build. Give them the path, the step count, the commit warning
and `/gku:review` for when the work is done — and say that `/gku:implement` will ask before
touching a manual plan, so the file is not a trap if they change their mind.
