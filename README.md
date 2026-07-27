# claude-skills

**🇬🇧 English** · [🇺🇦 Українська](README.uk.md)

<p>
  <img src="https://img.shields.io/badge/Claude_Code-D97757?style=for-the-badge&logo=claude&logoColor=white" alt="Claude Code" /> <img src="https://img.shields.io/badge/License-MIT-3DA639?style=for-the-badge" alt="License: MIT" /> <img src="https://img.shields.io/badge/macOS_%7C_Linux_%7C_Windows-4A4A4A?style=for-the-badge" alt="macOS | Linux | Windows" /> <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker" />
</p>

Six skills for [Claude Code](https://claude.com/claude-code) that cover an ordinary
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
- [The six skills](#the-six-skills)
- [A worked example](#a-worked-example-start-to-finish)
- [Each skill in detail](#each-skill-in-detail)
- [Writing a task file](#writing-a-task-file)
- [Using these on a Pro plan](#using-these-on-a-pro-plan)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## What is this, exactly?

A **skill** is a set of instructions you can call by name in Claude Code. Instead of
explaining what a good code review looks like every time, you type `/review` and Claude
follows a procedure that was written once and refined.

You call them with a slash, like `/review`, in the Claude Code chat.

They are **not** magic and they are **not** automatic. Every one of them does something you
could do yourself; they just do it consistently and without forgetting the boring parts —
which is exactly where mistakes come from.

Four of them (`/plan`, `/review`, `/pr-review`, `/verify`) never change your code at all.
Two of them do (`/implement`, `/pr-resolve`), and both tell you what they are about to do.

## Before you start

You need:

1. **Claude Code** installed and working — [installation guide](https://docs.claude.com/en/docs/claude-code/overview).
2. **git** — you have this already if you are cloning repositories.
   **On Windows, install [Git for Windows](https://git-scm.com/download/win)**, which includes
   Git Bash. Claude Code uses it to run commands, and these skills assume it is there.
3. **The GitHub CLI (`gh`)**, for the two pull-request skills:

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

   `/plan`, `/implement`, `/review` and `/verify` work without `gh`. Only `/pr-review` and
   `/pr-resolve` need it, because they talk to GitHub.

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
/plugin install toolkit@grinchenkoedu
```

That is all. Type `/` and you will see `/plan`, `/implement`, `/review`, `/pr-review`,
`/pr-resolve` and `/verify` in the list.

To update later:

```
/plugin marketplace update grinchenkoedu
```

<details>
<summary>Installing without the plugin system</summary>

macOS, Linux, or Git Bash on Windows:

```bash
git clone https://github.com/grinchenkoedu/claude-skills.git
mkdir -p ~/.claude/skills
cp -R claude-skills/plugins/toolkit/skills/* ~/.claude/skills/
cp -R claude-skills/plugins/toolkit/reference ~/.claude/skills/reference
```

Windows PowerShell:

```powershell
git clone https://github.com/grinchenkoedu/claude-skills.git
New-Item -ItemType Directory -Force "$HOME\.claude\skills" | Out-Null
Copy-Item -Recurse -Force claude-skills\plugins\toolkit\skills\* "$HOME\.claude\skills\"
Copy-Item -Recurse -Force claude-skills\plugins\toolkit\reference "$HOME\.claude\skills\reference"
```

The plugin route is easier to keep up to date. Use this only if you have a reason to.
</details>

## The six skills

They follow the order of the work:

```
   /plan  ──▶  /implement  ──▶  /review  ──▶  open a pull request
                                                      │
                                    ┌─────────────────┴──────────────────┐
                                    ▼                                    ▼
                              /pr-review                           /pr-resolve
                        (someone else's PR)                  (comments on yours)
                                    │                                    │
                                    └─────────────▶ /verify ◀────────────┘
```

| Command | What it does | Changes your code? |
|---|---|---|
| `/plan` | Turns a request into a concrete plan, checked against the real code | No |
| `/implement` | Builds the plan, step by step, ticking off progress as it goes | **Yes** |
| `/review` | Checks your own changes before you push them | No |
| `/pr-review` | Reviews someone else's pull request properly | No |
| `/pr-resolve` | Works through the review comments on *your* pull request | **Yes** |
| `/verify` | Runs the tests and drives the real thing to prove it works | No |

You do not have to use all of them, or use them in order. `/review` on its own, before every
push, is already worth it.

## A worked example, start to finish

Say someone reports: *the statistics export merges two departments that happen to have the
same name.*

**1. Work out what is actually wrong.**

```
/plan the statistics export merges departments that have the same name
```

> **On quotes:** you do not need them. What you type is passed to the skill as plain text —
> there is no shell involved, so nothing needs escaping, and apostrophes are fine. Quotes are
> only worth using when you add a flag after a description, to mark where the description ends:
> `/implement "add a CSV export" --continue`.

Claude finds the export code, reads it, checks the database to see whether same-named
departments really exist, and writes a plan to `.tasks/export-department-collision.md` — with
the cause, the fix, acceptance criteria and ordered steps. Read it. **If the plan is wrong,
say so now** — it is much cheaper to fix a plan than a half-built change.

**2. Build it.**

```
/implement .tasks/export-department-collision.md
```

It creates a branch, works through the steps in order, ticks each one off in the task file,
and runs the tests. You can watch every edit and stop at any time.

> **If you run out of usage partway through, that is fine.** The finished steps are ticked in
> the task file. When your limit resets, `/implement .tasks/export-department-collision.md
> --continue` picks up exactly where it stopped.

**3. Check your own work.**

```
/review
```

You get a short list: blockers to fix first, warnings worth a look, and nits you can ignore.
Fix the blockers, then push and open a pull request as you normally would.

**4. Deal with the review comments.**

An automated reviewer comments on the pull request. Instead of fixing each one by hand:

```
/pr-resolve 42
```

It checks **every comment against the actual code first**, then fixes the ones that are
right, pushes back with evidence on the ones that are wrong, and asks you about anything
genuinely ambiguous. One commit per fix, one reply per comment.

**5. Prove it works.**

```
/verify
```

Runs the tests *and* actually runs the export, then gives a verdict — including an honest
list of anything it could not check.

## Each skill in detail

### `/plan` — work out what to build

```
/plan students cannot download their individual plan
/plan .tasks/new-grade-export.md
/plan --review .tasks/proposed-approach.md
```

Give it a sentence, or point it at a markdown file with a longer description. It works out
whether you are describing a bug, a feature, a question or a data problem — these need very
different answers — then reads the code and checks its assumptions against real data before
proposing anything.

Output goes to `.tasks/<name>.md`: the cause or design, acceptance criteria, ordered steps,
and how to check the result.

`--review` is for when the file *already* proposes a solution: it judges that proposal rather
than inventing a different one.

**It writes no code.** Use it when you are not yet sure what the right change is. For an
obvious one-line fix, skip it.

### `/implement` — build it

```
/implement .tasks/export-department-collision.md
/implement add a CSV option to the student export
/implement .tasks/big-task.md --continue
```

Works sequentially in your working tree — no background agents, nothing hidden. It creates a
branch if you are on the main one, follows the steps in order, checks each change as it lands,
writes tests, and runs the suite.

**The task file is also the progress log.** Each finished step gets ticked off with a note of
what landed, which is what makes `--continue` work after an interruption.

It stays inside the task. If it notices something else broken, it tells you at the end rather
than quietly fixing it — an implementation that wanders is one nobody can review.

### `/review` — check your own work

```
/review
/review --deep
/review --report
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

If the project has a lint command, it **lints the files you changed** and reports a parse error
as a blocker. In a repository with no tests and no working CI, this is the only mechanical check
standing between a syntax error and a live site. It will tell you when the linter runs a newer
language version than the project targets — passing a PHP 8 parser proves nothing about a
project that declares `>=7.4`.

`--deep` allows one helper agent to double-check callers of code you renamed. It costs more;
use it when you have touched shared code.

### `/pr-review` — review someone else's pull request

```
/pr-review 42
/pr-review https://github.com/grinchenkoedu/local_gdo/pull/42
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

### `/pr-resolve` — act on comments on your pull request

```
/pr-resolve 42
/pr-resolve 42 --dry-run
```

For **your own** pull request. It collects every comment, and — this is the important part —
**gives each one a verdict before changing any code**:

- **agree** → the smallest fix that resolves it, as its own commit;
- **disagree** → no code change, and a polite reply with the file and line that answers it;
- **unclear** → it asks you, batching all such questions into one interruption.

Then it pushes and replies to each thread.

Reviewers — human and automated alike — are sometimes wrong. Fixing a confidently-worded false
positive is how you introduce a real bug. Start with `--dry-run` to see the verdicts before
anything changes.

### `/verify` — prove it works

```
/verify
/verify 42
/verify --tests-only
```

Tests passing and a feature working are two different claims. This makes both separately.

It runs the project's test suite (quoting the actual result line, not "tests pass"), then
**runs the real thing** — the command, the page, the function — and checks the effect.

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

Keep them in `.tasks/` — `/plan` writes there, `/implement` reads and updates them. Add
`.tasks/` to `.gitignore` unless you want the briefs in version control.

**Be specific about what "done" means.** That list becomes the acceptance criteria, which is
what `/implement` builds against and what `/verify` checks. Vague criteria produce vague work.

## Using these on a Pro plan

Claude Code on a Pro subscription has usage limits that reset periodically. These skills were
written with that in mind — the expensive patterns (fleets of parallel agents, background
workflows, reading whole repositories) are deliberately absent.

How they keep the cost down:

- **No sub-agents by default.** At most one, only when you ask with `--deep`.
- **The stack is detected once**, then cached in `.claude/repo-profile.json` and reused by all
  six skills. Add that file to `.gitignore` — it describes your machine.
- **Reading is capped.** At most five files read in full; everything else judged from the
  diff. When a skill judged a file from the diff alone, it says so.
- **Answers go in the chat**, not into generated report files. A report is written only when
  there is a blocker, or when you ask with `--report`.
- **`/implement` is resumable**, so hitting a limit costs you nothing but time.

Practical advice:

1. **Stay on Sonnet.** Nothing here needs a larger model. Check with `/model`.
2. **Use `/clear` between unrelated tasks.** A long conversation is re-sent with every
   message, so an unrelated three-hour history makes every request more expensive.
3. **Run `/review` often and `--deep` rarely.** The plain version catches most of it.
4. **Prefer `/implement` on a written task file** over a vague sentence — it gets it right the
   first time more often, and a redo costs more than a good brief.
5. **If you hit a limit mid-build, do not start over.** Wait for the reset and use
   `--continue`.

## Troubleshooting

**The commands do not appear after installing.**
Restart Claude Code. Check with `/plugin` that `toolkit@grinchenkoedu` is listed.

**`/pr-review` says it cannot find the pull request.**
Check `gh auth status`. For a private repository you need access, and the token needs the
`repo` scope. Re-authenticate with `gh auth login --scopes "repo,read:org"`.

**A skill got the test command wrong.**
It caches what it detected. Delete `.claude/repo-profile.json` and run again, or pass
`--reprofile`. If the project's real command lives somewhere unusual, put it in the
repository's `AGENTS.md` — the skills read that file.

**`/implement` refuses to start.**
Usually uncommitted changes it did not make. Commit or stash them first — it will not build on
top of work it cannot account for.

**`/verify` says "cannot tell".**
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

Add a skill as `plugins/toolkit/skills/<name>/SKILL.md`, with `name` and `description` in the
frontmatter.

Keep to the conventions the existing skills follow, because they are what make these usable on
a limited plan:

- no sub-agents by default, at most one behind `--deep`;
- no background workflows or agent fleets;
- read the diff, not the repository, with an explicit cap;
- answer in the chat; write a file only on a blocker or on request;
- no absolute paths from your own machine in `SKILL.md`;
- nothing specific to one repository — read the project's own conventions instead.

The shared detection logic lives in `plugins/toolkit/reference/repo-profile.md`. If your skill
needs to know something about the project, add it there rather than detecting it separately.

## Licence

MIT — see [LICENSE](LICENSE).
