# claude-skills

**🇬🇧 English** · [🇺🇦 Українська](README.uk.md)

<p>
  <img src="https://img.shields.io/badge/Claude_Code-D97757?style=for-the-badge&logo=claude&logoColor=white" alt="Claude Code" /> <img src="https://img.shields.io/badge/License-MIT-3DA639?style=for-the-badge" alt="License: MIT" /> <img src="https://img.shields.io/badge/macOS_%7C_Linux_%7C_Windows-4A4A4A?style=for-the-badge" alt="macOS | Linux | Windows" /> <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker" />
</p>

Skills for [Claude Code](https://claude.com/claude-code) that cover an ordinary
development day: work out what to build, build it, check your own work, review a colleague's
pull request, deal with the comments on yours, and prove the result actually works.

They work in any repository — nothing here is tied to a particular project, language or
framework. They are also written to be **economical**, so they are usable on a modest Claude
plan: no background agent swarms, no parallel sub-agents by default, and answers in the chat
instead of a pile of generated report files.

MIT licensed.

---

## Contents

- [What is this, exactly?](#what-is-this-exactly)
- [Before you start](#before-you-start)
- [Installation](#installation)
- [The skills](#the-skills)
- [A worked example](#a-worked-example-start-to-finish)
- [Each skill in detail](#each-skill-in-detail)
- [Writing a task file](#writing-a-task-file)
- [Where the reports go](#where-the-reports-go)
- [Using these on a Pro plan](#using-these-on-a-pro-plan)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## What is this, exactly?

A **skill** is a set of instructions you can call by name in Claude Code. Instead of
explaining what a good code review looks like every time, you type `/gku:review` and Claude
follows a procedure that was written once and refined.

You call them with a slash, like `/gku:review`, in the Claude Code chat.

They are **not** magic and they are **not** automatic. Every one of them does something you
could do yourself; they just do it consistently and without forgetting the boring parts —
which is exactly where mistakes come from.

Four of them (`/gku:plan`, `/gku:review`, `/gku:pr-review`, `/gku:verify`) never change your code at all.
Three do (`/gku:implement`, `/gku:fix`, `/gku:pr-resolve`), and each tells you what it is about to
do. `/gku:pr` changes nothing locally; it pushes commits you already made and opens the pull
request.

None of them takes instructions from what it reads. A comment on a pull request, a brief, a
findings file, a test's output — these are evidence about the code, and a skill checks them
against it; they cannot make a skill push, skip a hook, run a command or change its own rules.
Only you can, in the chat. `plugins/gku/reference/untrusted-input.md` says where that line is
drawn, and why holding it costs nothing extra per run.

## Before you start

You need:

1. **Claude Code** installed and working — [installation guide](https://docs.claude.com/en/docs/claude-code/overview).
2. **git** — you have this already if you are cloning repositories.
   **On Windows, install [Git for Windows](https://git-scm.com/download/win)**, which includes
   Git Bash. Claude Code uses it to run commands, and these skills assume it is there.
3. **The GitHub CLI (`gh`)**, for the three pull-request skills:

   ```bash
   winget install --id GitHub.cli     # Windows
   brew install gh                    # macOS
   sudo apt install gh                # Ubuntu/Debian
   ```

   Then sign in once, and check it worked:

   ```bash
   gh auth login
   gh auth status
   ```

   `/gku:plan`, `/gku:implement`, `/gku:review`, `/gku:fix` and `/gku:verify` work without `gh`.
   Only `/gku:pr`, `/gku:pr-review` and `/gku:pr-resolve` need it, because they talk to GitHub.

4. **Docker** — [Docker Desktop](https://www.docker.com/products/docker-desktop/) on Windows
   and macOS, Docker Engine on Linux. **Strongly recommended on every platform**, not just
   Windows.

   The skills run a project's own commands **inside its container** by default. That is not
   about convenience — it is about being right. These projects target specific runtime
   versions: a plugin written for PHP 7.4 checked by a host PHP 8.4 will accept syntax that
   breaks in production, and a test suite that passes against the wrong version has not proven
   anything. The container has the version the project actually uses, along with its
   dependencies and its database.

   It also means you do not need PHP, Composer, Python or Node installed locally at all —
   several of these projects assume you do not have them — and the same commands work
   identically on Windows, macOS, Linux and WSL.

   Without Docker the skills still work, falling back to whatever is on your machine, and they
   will tell you they did. If the versions differ from the project's, treat a green run with
   suspicion.

**Windows works.** Use Git Bash, as in step 2. The skills detect your platform on first use and
store commands that work there. WSL also works and behaves like Linux.

## Installation

In Claude Code, run these two commands:

```
/plugin marketplace add grinchenkoedu/claude-skills
/plugin install gku@grinchenkoedu
```

That is all. Type `/` and you will see `/gku:plan`, `/gku:implement`, `/gku:review`, `/gku:fix`,
`/gku:pr`, `/gku:pr-review`, `/gku:pr-resolve` and `/gku:verify` in the list.

### Updating

The skills are improved regularly. To pull the latest:

```
/plugin marketplace update grinchenkoedu
/reload-plugins
```

The first refreshes the marketplace from GitHub; the second reloads skills in the current
session so you do not have to restart.

If you would rather not think about it, `/plugin` opens the manager where you can check what is
installed and update from there.

**Why you always get updates:** this plugin deliberately omits the `version` field in its
manifest. Claude Code then treats **every commit as a new version**, so an update always brings
the latest. Had a version been declared, you would receive nothing until it was bumped — and a
forgotten bump means silently running months-old skills.

<details>
<summary>If you installed by copying the files instead</summary>

Re-copy them, since nothing tracks the source:

```bash
cd claude-skills && git pull
cp -R plugins/gku/skills/* ~/.claude/skills/
cp -R plugins/gku/reference ~/.claude/skills/reference
cp -R plugins/gku/templates ~/.claude/skills/templates
```

This is the main reason to prefer the plugin route.
</details>

<details>
<summary>Installing without the plugin system</summary>

macOS, Linux, or Git Bash on Windows:

```bash
git clone https://github.com/grinchenkoedu/claude-skills.git
mkdir -p ~/.claude/skills
cp -R claude-skills/plugins/gku/skills/* ~/.claude/skills/
cp -R claude-skills/plugins/gku/reference ~/.claude/skills/reference
cp -R claude-skills/plugins/gku/templates ~/.claude/skills/templates
```

Windows PowerShell:

```powershell
git clone https://github.com/grinchenkoedu/claude-skills.git
New-Item -ItemType Directory -Force "$HOME\.claude\skills" | Out-Null
Copy-Item -Recurse -Force claude-skills\plugins\gku\skills\* "$HOME\.claude\skills\"
Copy-Item -Recurse -Force claude-skills\plugins\gku\reference "$HOME\.claude\skills\reference"
Copy-Item -Recurse -Force claude-skills\plugins\gku\templates "$HOME\.claude\skills\templates"
```

The plugin route is easier to keep up to date. Use this only if you have a reason to.

> **Two differences with this route.** The skills are **not namespaced** — they install as
> `/review`, `/init`, `/verify` rather than `/gku:review`. That means **`/init`, `/review` and
> `/verify` replace Claude Code's own commands of those names**, and `/init` in particular does
> a similar job, so you will not be able to tell which one you invoked. Rename the directories
> under `~/.claude/skills/` if you would rather keep the originals.
</details>

## The skills

They follow the order of the work:

```
   /gku:init ──▶ /gku:plan ──▶ /gku:implement ──▶ /gku:review ⇄ /gku:fix ──▶ /gku:pr
(once per repo)                                                                 │
                                       ┌────────────────────────────────────────┤
                                       ▼                                        ▼
                                /gku:pr-review                          /gku:pr-resolve
                            (someone else's PR)                      (comments on yours)
                                       │                                        │
                                       └───────────────▶ /gku:verify ◀──────────┘
```

| Command | What it does | Changes your code? |
|---|---|---|
| `/gku:init` | Writes this repository's `CLAUDE.md` — commands plus its family's rules | **Yes** (one file) |
| `/gku:plan` | Turns a request into a concrete plan, checked against the real code | No |
| `/gku:implement` | Builds the plan, step by step, ticking off progress as it goes | **Yes** |
| `/gku:review` | Checks your own changes before you push them | No |
| `/gku:fix` | Investigates a symptom, or applies review findings — one commit each | **Yes** |
| `/gku:pr` | Opens the pull request for this branch, or updates the existing one | No (pushes commits you made) |
| `/gku:pr-review` | Reviews someone else's pull request properly | No |
| `/gku:pr-resolve` | Works through the review comments on *your* pull request | **Yes** |
| `/gku:verify` | Runs the tests and drives the real thing to prove it works | No |

You do not have to use all of them, or use them in order. `/gku:review` on its own, before every
push, is already worth it.

## A worked example, start to finish

Say someone reports: *the statistics export merges two departments that happen to have the
same name.*

**1. Work out what is actually wrong.**

```
/gku:plan the statistics export merges departments that have the same name
```

> **On quotes:** you do not need them. What you type is passed to the skill as plain text —
> there is no shell involved, so nothing needs escaping, and apostrophes are fine. Quotes are
> only worth using when you add a flag after a description, to mark where the description ends:
> `/gku:implement "add a CSV export" --continue`.

Claude finds the export code, reads it, checks the database to see whether same-named
departments really exist, and writes a plan to `.tasks/export-department-collision.md` — with
the cause, the fix, acceptance criteria and ordered steps. Read it. **If the plan is wrong,
say so now** — it is much cheaper to fix a plan than a half-built change.

**2. Build it.**

```
/gku:implement .tasks/export-department-collision.md
```

It creates a branch, works through the steps in order, ticks each one off in the task file,
and runs the tests. You can watch every edit and stop at any time.

> **If you run out of usage partway through, that is fine.** The finished steps are ticked in
> the task file. When your limit resets, `/gku:implement .tasks/export-department-collision.md
> --continue` picks up exactly where it stopped.

**3. Check your own work.**

```
/gku:review
```

You get a short list: blockers to fix first, warnings worth a look, and nits you can ignore. It
ends by naming what to run next, so you are not left holding a list.

**4. Apply the fixes.**

```
/gku:fix
```

It picks up the findings from the review you just ran, **re-checks each one against the code**
before touching it — some will already be fixed, and some will turn out to be wrong — then
applies the blockers and warnings, one commit each, and re-runs the tests. Nits are listed, not
applied, unless you add `--nits`.

> The same command also starts from cold. `/gku:fix the export merges same-named departments`
> in a brand-new session investigates the report first — finds the code, reproduces it, proves
> the cause — and then fixes it, rather than handing you a plan to run.

**5. Open the pull request.**

```
/gku:pr
```

It reads the whole branch, checks that it **reads as one pull request** — and asks first if it
looks like a feature with an unrelated fix riding along — then pushes and writes a description
from the actual diff, using your repository's template if it has one.

**6. Deal with the review comments.**

An automated reviewer comments on the pull request. Instead of fixing each one by hand:

```
/gku:pr-resolve 42
```

It checks **every comment against the actual code first**, then fixes the ones that are
right, pushes back with evidence on the ones that are wrong, and asks you about anything
genuinely ambiguous. One commit per fix, one reply per comment.

**7. Prove it works.**

```
/gku:verify
```

Runs the tests *and* actually runs the export, then gives a verdict — including an honest
list of anything it could not check.

## Each skill in detail

### `/gku:init` — give this repository a CLAUDE.md

```
/gku:init
/gku:init --refresh
/gku:init --dry-run
```

`CLAUDE.md` is read at the start of every session in a repository, so it is where the build and
test commands and the handful of rules that actually get broken here belong. `/gku:init` detects the
project family — Moodle plugin, PHP app, CMS, Python — fills in the real commands, and adds that
family's conventions, security rules, design priorities (readable before maintainable before
extendable before efficient) and where long-running work belongs.

The shared part sits inside markers:

```markdown
<!-- toolkit:begin family-rules -->
...maintained by /gku:init...
<!-- toolkit:end family-rules -->
```

`--refresh` replaces **only** that block, so anything you wrote yourself survives.

If a `CLAUDE.md` already exists it is **read and judged first**: correct commands and a current
family block get reported as *already fine* with nothing written, because churning a good file
is not an improvement. A stale command or a rule the code contradicts is listed for you rather
than silently rewritten. A file without markers is never overwritten — it asks.

It also leaves an `AGENTS.md` stub pointing at `CLAUDE.md`, so other agents find the same rules
without a second copy that drifts. A stub rather than a symlink, because git checks symlinks out
as plain text files on Windows.

Run it once per repository, and again when the family rules improve.

### `/gku:plan` — work out what to build

```
/gku:plan students cannot download their individual plan
/gku:plan .tasks/new-grade-export.md
/gku:plan --review .tasks/proposed-approach.md
```

Give it a sentence, or point it at a markdown file with a longer description. It works out
whether you are describing a bug, a feature, a question or a data problem — these need very
different answers — then reads the code and checks its assumptions against real data before
proposing anything.

Output goes to `.tasks/<name>.md`: the cause or design, acceptance criteria, ordered steps,
and how to check the result. For a web application the design also says which steps run in the
background rather than in the request, using the mechanism the project already has.

`--review` is for when the file *already* proposes a solution: it judges that proposal rather
than inventing a different one.

**It writes no code.** Use it when you are not yet sure what the right change is, or when the
answer needs agreeing before anyone builds it. For something that is simply broken and wants
fixing, `/gku:fix` does the same investigation and then acts on it.

### `/gku:implement` — build it

```
/gku:implement .tasks/export-department-collision.md
/gku:implement add a CSV option to the student export
/gku:implement .tasks/big-task.md --continue
```

Works sequentially in your working tree — no background agents, nothing hidden. It creates a
branch if you are on the main one, follows the steps in order, checks each change as it lands,
writes tests, and runs the suite.

**The task file is also the progress log.** Each finished step gets ticked off with a note of
what landed, which is what makes `--continue` work after an interruption.

It stays inside the task. If it notices something else broken, it tells you at the end rather
than quietly fixing it — an implementation that wanders is one nobody can review.

### `/gku:review` — check your own work

```
/gku:review
/gku:review --deep
/gku:review --report
```

**The one to use every day.** Run it before you push. It reads your changes, applies your
repository's own conventions (from `AGENTS.md`, `CLAUDE.md` or whatever the project has), and
gives you a list sorted by severity:

- **BLOCKER** — do not push this. Committed passwords, lost data, a renamed function still
  called elsewhere, unescaped user input, a Moodle change with no `version.php` bump.
- **WARNING** — fix before asking for review. Untested logic, an unhandled error path, a loop
  that can run forever.
- **NIT** — take it or leave it.

It also checks whether your **tests actually prove anything** — a test with no real assertion,
or one that mocks away the exact thing you changed, passes while proving nothing.

Every review includes a **security pass** against the well-known flaws — a request value
reaching SQL, a shell, the filesystem or the page unescaped; an entry point with no login or
permission check; a record anyone can read by changing an id; a form bound straight to a model;
a state change with no CSRF token; a committed secret; an upload stored where the server would
run it; the server fetching a URL the user chose; weak tokens and hashing; a dependency with a
published advisory. The list, with the code pattern and the proof for each, lives in
`plugins/gku/reference/security-checklist.md`. A finding names the line and the one input that
shows it — a single quote, `../`, a `<b>` tag — and nothing more than that is ever built. The
closing line of the review names which parts of the pass were done, so a skipped part is
visible rather than silent.

If the project has a lint command, it **lints the files you changed** and reports a parse error
as a blocker. In a repository with no tests and no working CI, this is the only mechanical check
standing between a syntax error and a live site. It will tell you when the linter runs a newer
language version than the project targets — passing a PHP 8 parser proves nothing about a
project that declares `>=7.4`.

`--deep` allows one helper agent to double-check callers of code you renamed. It costs more;
use it when you have touched shared code.

It ends by naming the next command — `/gku:fix` when there is something to fix, `/gku:pr` when
there is not. It never applies anything itself.

### `/gku:fix` — find what is wrong, then fix it

```
/gku:fix
/gku:fix .gku/reports/review-my-branch-20260824-143201.md
/gku:fix the export blows up when a department has no head
/gku:fix --nits
/gku:fix --dry-run
```

Two jobs in one command, because in practice they are the same job.

**Given findings**, it applies them — **blockers and warnings by default**, one commit each,
then re-runs the tests. Nits are listed rather than applied; they are matters of taste and they
bury the real changes in a diff somebody has to read. `--nits` takes them too. This is the half
`/gku:review` deliberately leaves undone.

**Given a symptom** — a sentence describing something broken — **it investigates first**, the
way `/gku:plan` does: work out whether you are describing a bug, a feature, a question or a data
problem; find the code; reproduce it; prove the cause. Only then does it edit anything.

The difference from `/gku:plan` is what happens next: **when the cause is proven and the fix is
clear, it acts.** No plan file, no approval step for your own bug report. It tells you what it
found in two or three lines and fixes it. It asks only when the answer would change the fix —
two defensible options, a cause outside this branch, or something that turns out to be a feature
rather than a fix. *A question it could answer by reading more code is not a question.*

That is what makes it a reasonable way to **open a fresh session on a bug report**. Nothing
needs to be in the conversation already:

- **with nothing** — findings from a `/gku:review` earlier in the conversation, or that review
  run inline if there are none;
- **with a file** — a report from `.gku/reports/`, or any markdown holding findings;
- **with a sentence** — investigate it, then fix it.

It is explicit about the difference between a **proven cause** and a **hypothesis**, and it says
which one it acted on. When it reproduced the symptom, it re-runs that same reproduction after
the fix — a green test suite does not prove your bug is gone; the thing that used to fail no
longer failing does.

**It re-checks every finding against the code before editing anything**, including findings it
produced itself a minute ago. Findings go stale: the file moved, somebody already fixed it, or
the claim was wrong to begin with. Each one comes back *fixed*, *already resolved*, *does not
hold* with the evidence, or *needs your decision* — and the ones that do not hold cost you
nothing but a line in the report.

`--dry-run` stops after the diagnosis, which is `/gku:fix` behaving like `/gku:plan` when that
is what you want from it.

It applies **the smallest change that resolves each finding**, with no drive-by refactoring, and
it never pushes. When a "fix" turns out to need a redesign, it stops on that finding and says so
rather than quietly building something larger.

> It will not re-run the review afterwards, on purpose. Review → fix → review → fix is a loop
> that spends a lot of usage for very little. It names the next command; you choose it.

### `/gku:pr` — open the pull request

```
/gku:pr
/gku:pr "Keep same-named departments separate in the statistics export"
/gku:pr --draft
/gku:pr --dry-run
```

Opens the pull request for the current branch, or updates the one already linked to it. It
pushes commits you have already made; it never commits for you, never merges, and never
force-pushes.

**The part worth having: it checks the branch reads as one pull request.** A branch carrying a
feature *and* an unrelated bug fix *and* a formatting sweep is three reviews pretending to be
one, and that is where review quality quietly disappears. When it finds that, it stops, shows
you the groups it found — the sentence describing each, its commits, its files — and asks:

- **open one pull request anyway**, which is often the right answer for a small passenger; or
- **stop, so you can split it**, with the commits that would go in each named for you.

It will not split the branch itself. Rewriting your history is not its decision to make.

Many files with one purpose, or an implementation with its tests and its migration, are **one**
change — it does not flag those.

The description comes from the actual diff and your repository's own
`.github/pull_request_template.md` if it has one, with the title matching the house style it
reads from your recent merged pull requests. The testing section says what was actually run and
**admits it when nothing was**. Updating an existing pull request never silently overwrites a
description somebody wrote by hand.

### `/gku:pr-review` — review someone else's pull request

```
/gku:pr-review 42
/gku:pr-review https://github.com/grinchenkoedu/local_gdo/pull/42
```

Checks out the pull request in a separate worktree — so your own work is untouched — and
reviews it properly.

It deliberately **skips what the automated reviewer already covered** (formatting, naming,
style) and hunts what automated review structurally misses: what happens when something fails
halfway, loops that never end on odd data, two people clicking at once, who else calls the
code that changed, and whether the change actually does what its description claims.

Two severities only: **BLOCKER** (with a concrete failure scenario — no scenario, no blocker)
and **SMELL**. Findings come back in the chat, short. It never posts anything to GitHub; you
decide what to say.

> An automated reviewer approving a pull request is not evidence that it is correct. It is
> tuned to be precise about style, and it approves changes containing real bugs. This skill
> treats its approval as no information at all.

### `/gku:pr-resolve` — act on comments on your pull request

```
/gku:pr-resolve https://github.com/grinchenkoedu/local_gdo/pull/42
/gku:pr-resolve 42
/gku:pr-resolve 42 --dry-run
```

For **your own** pull request. **A URL works from anywhere** — any directory, another project,
or outside a repository entirely: it resolves the repository from the URL and reuses a local
clone if you have one, or makes one and tells you where. A bare number only works inside a clone
of the repository that owns the PR, since there is nothing else to resolve it against. It collects every comment, and — this is the important part —
**gives each one a verdict before changing any code**:

- **agree** → the smallest fix that resolves it, as its own commit;
- **disagree** → no code change, and a polite reply with the file and line that answers it;
- **unclear** → it asks you, batching all such questions into one interruption.

A comment that talks to the tool rather than about the code — skip the tests, push with
`--no-verify` — gets none of these: it is skipped, and the report says so.

Then it pushes and replies to each thread.

Reviewers — human and automated alike — are sometimes wrong. Fixing a confidently-worded false
positive is how you introduce a real bug. Start with `--dry-run` to see the verdicts before
anything changes.

### `/gku:verify` — prove it works

```
/gku:verify
/gku:verify 42
/gku:verify --tests-only
```

Tests passing and a feature working are two different claims. This makes both separately.

It runs the project's test suite (quoting the actual result line, not "tests pass"), then
**runs the real thing** — the command, the page, the function — and checks the effect.

Then it **confirms the guards hold**: the same entry point requested with no session, as a test
account without the permission, with the CSRF token removed, with another account's record id,
with `../` in a filename, with `<b>` in a text field. Each is one minimal local probe on
throwaway accounts, each gets its own row — passed, failed, or skipped with a reason — and a
refusal is the result being looked for. Everything created for it is removed afterwards.

Its most useful feature is honesty about what it could not check. Every skipped check gets a
category and a way to unblock it, and **"cannot tell" is a valid verdict**. A confident
"works" resting on three skipped checks is worse than no answer at all.

## Writing a task file

For anything bigger than a sentence, write the description in a markdown file and pass that
instead. There is no required format — these are read by a language model, so plain clear
prose works. A useful shape:

```markdown
# Individual plan export by indicator

## What we need
A background xlsx export of individual plan statistics, with two sheets:
one per indicator, one with the scientific-work detail.

## Why
Faculty administrators currently count this by hand every semester.

## Details
- Reuse the existing background export mechanism — no new infrastructure.
- Rows group by indicator, then faculty, then department.
- Departments in different faculties can share a name; they must not be merged.

## Done when
- [ ] An administrator can request the export from the statistics page
- [ ] The file has both sheets, with numbers as numbers (sortable in Excel)
- [ ] Same-named departments in different faculties stay separate
```

Keep them in `.tasks/` — `/gku:plan` writes there, `/gku:implement` reads and updates them. Add
`.tasks/` to `.gitignore` unless you want the briefs in version control.

**Be specific about what "done" means.** That list becomes the acceptance criteria, which is
what `/gku:implement` builds against and what `/gku:verify` checks. Vague criteria produce vague work.

## Where the reports go

Most answers stay in the chat. When a skill does write a file — `/gku:review`, `/gku:verify` and
`/gku:pr-review`, on `--report` or when they find a blocker — it goes into one ignored directory,
never the repository root:

```
.gku/reports/review-security-pass-20260824-143201.md
.gku/reports/review-security-pass-20260824-171045.md
.gku/reports/verify-security-pass-20260824-172230.md
.gku/reports/pr-review-pr-118-20260824-093700.md
```

The name is `<kind>-<branch-or-pr>-<UTC timestamp>.md`. The prefix says which skill wrote it,
the timestamp keeps a second run on the same branch from overwriting the first, and sorting the
directory sorts it by kind, then branch, then time. Nothing is ever overwritten, so a series of
reviews collects there for comparison.

The skills add `.gku/` to your `.gitignore` the first time they write one — these are working
notes about a moment in your working tree, not project history. Delete the directory whenever
you like; nothing reads it except you and `/gku:fix <path>`.

## Using these on a Pro plan

Claude Code on a Pro subscription has usage limits that reset periodically. These skills were
written with that in mind — the expensive patterns (fleets of parallel agents, background
workflows, reading whole repositories) are deliberately absent.

How they keep the cost down:

- **No sub-agents by default.** At most one, only when you ask with `--deep`.
- **The stack is detected once**, then cached in `.claude/repo-profile.json` and reused by every
  skill. Add that file to `.gitignore` — it describes your machine.
- **Reading is capped.** At most five files read in full; everything else judged from the
  diff. When a skill judged a file from the diff alone, it says so.
- **Answers go in the chat**, not into generated report files. A report is written only when
  there is a blocker, or when you ask with `--report` — and it goes to `.gku/reports/`, never
  the repository root (see [Where the reports go](#where-the-reports-go)).
- **`/gku:implement` is resumable**, so hitting a limit costs you nothing but time.

Practical advice:

1. **Stay on Sonnet.** Nothing here needs a larger model. Check with `/model`.
2. **Use `/clear` between unrelated tasks.** A long conversation is re-sent with every
   message, so an unrelated three-hour history makes every request more expensive.
3. **Run `/gku:review` often and `--deep` rarely.** The plain version catches most of it.
   `/gku:fix` deliberately does not re-review afterwards — one review, one fix pass, then decide.
   Looping the two is the easiest way to burn a limit on diminishing returns.
4. **Prefer `/gku:implement` on a written task file** over a vague sentence — it gets it right the
   first time more often, and a redo costs more than a good brief.
5. **If you hit a limit mid-build, do not start over.** Wait for the reset and use
   `--continue`.

## Troubleshooting

**The commands do not appear after installing.**
Restart Claude Code. Check with `/plugin` that `gku@grinchenkoedu` is listed.

**`/gku:pr-review` says it cannot find the pull request.**
Check `gh auth status`. For a private repository you need access, and the token needs the
`repo` scope. Re-authenticate with `gh auth login --scopes "repo,read:org"`.

**A skill got the test command wrong.**
It caches what it detected. Delete `.claude/repo-profile.json` and run again, or pass
`--reprofile`. If the project's real command lives somewhere unusual, put it in the
repository's `AGENTS.md` — the skills read that file.

**`/gku:implement` refuses to start.**
Usually uncommitted changes it did not make. Commit or stash them first — it will not build on
top of work it cannot account for.

**`/gku:pr` says my branch looks like more than one pull request.**
It found groups of commits with no thread between them. Read the groups it printed: if the extra
part is small and related enough, tell it to open one pull request anyway — that is a normal
answer, not a workaround. If they really are separate, it names which commits belong where, but
you split the branch yourself; it will not rewrite your history.

**`/gku:fix` changed nothing and said the findings do not hold.**
Working as intended. It re-checks each finding against the code first, and a review — including
its own — is sometimes wrong about your codebase. Read the evidence it gave per finding; if you
disagree with the re-check, say so and it will fix it.

**`/gku:fix` called its cause a "hypothesis".**
It could not reproduce the symptom, so it is telling you the difference between what it proved
and what it inferred from reading the code. Weigh the fix accordingly. Giving it the input that
reproduces the problem — the record id, the command, the request — turns the hypothesis into a
proven cause on the next run.

**`/gku:fix` investigated and then asked me a question instead of fixing.**
It only does that when the answer changes the fix: two defensible options, a cause in code this
branch never touched, or something that turns out to be a feature rather than a bug. Answer it
and it carries on. If you want the diagnosis without any edits, use `--dry-run`.

**`/gku:verify` says "cannot tell".**
That is deliberate, not a failure. Read the blocked checks and their categories; each has a
one-line way to unblock it. A `HOSTED` blocker means the code needs its host application
(a Moodle plugin cannot run on its own) — that one is a fact about the project, not a problem
to fix.

**A skill says it fell back to the host instead of Docker.**
The daemon is not running, or Docker is not installed. Start Docker Desktop and delete
`.claude/repo-profile.json` so it redetects. Worth doing: on the host you are testing against
whatever versions your machine happens to have, which for these projects is often not the
version they target.

**"make: command not found".**
`make` is not part of a standard Windows install, and the skills should not be calling it —
they store the command from inside the `Makefile` rather than the `make` invocation. Delete
`.claude/repo-profile.json` and run again. If you want `make` anyway:
`winget install ezwinports.make`.

**On Windows: a Docker command fails with a strange path like `C:/Program Files/Git/app`.**
Git Bash rewrote the container path. The profile should store that command with
`MSYS_NO_PATHCONV=1` in front of it; delete `.claude/repo-profile.json` and let it redetect.
Projects with a `docker-compose.yml` avoid this entirely, since `docker compose exec` has no
mount argument to mangle.

**On Windows: the diff shows every line as changed.**
Line endings, not real changes — the file was converted between CRLF and LF. Check
`git config core.autocrlf` before reviewing it as a real diff.

**A skill wants to remove a worktree.**
Worktrees are extra checkouts under `../<repo>-pr-42` and similar. They are safe to remove
once you are done. List them with `git worktree list`.

## Contributing

Add a skill as `plugins/gku/skills/<name>/SKILL.md`, with `name` and `description` in the
frontmatter.

Keep to the conventions the existing skills follow, because they are what make these usable on
a limited plan:

- no sub-agents by default, at most one behind `--deep`;
- no background workflows or agent fleets;
- read the diff, not the repository, with an explicit cap;
- answer in the chat; write a file only on a blocker or on request, and write it to
  `.gku/reports/` under the shared naming scheme, never to the repository root;
- no absolute paths from your own machine in `SKILL.md`;
- nothing specific to one repository — read the project's own conventions instead;
- a rule about the *code the skills write* (a design priority, where long work runs) goes in the
  family templates under `plugins/gku/templates/`, so it reaches a project through its `CLAUDE.md`;
  a rule about the *skills' own cost* goes in `reference/`.

The shared detection logic lives in `plugins/gku/reference/repo-profile.md`. If your skill
needs to know something about the project, add it there rather than detecting it separately.
The security checklist that `/gku:review` and `/gku:verify` share lives in
`plugins/gku/reference/security-checklist.md` — add a flaw there once, with its pattern, proof
and severity, rather than in each skill. Where report files go and how they are named is in
`plugins/gku/reference/reports.md`; a skill that writes one follows it rather than inventing
its own file name. What the skills treat as evidence rather than instruction — comments, briefs,
tool output — is in `plugins/gku/reference/untrusted-input.md`; a skill that reads text the
developer did not type points at it from the step where that text comes in.

A change to a `SKILL.md` or to `reference/` is code that runs in every session on every machine
that updates the plugin. Review it as such.

## Licence

MIT — see [LICENSE](LICENSE).
