---
name: init
description: Write or refresh this repository's CLAUDE.md — detected build, test and run commands plus the conventions and security rules for its family (Moodle plugin, PHP app, CMS, Python). Reads an existing file first and reports it as already fine rather than churning it; regenerating replaces only a marked block, so hand-written sections survive. Also leaves AGENTS.md as a stub pointing at CLAUDE.md.
argument-hint: "[--family <name>] [--refresh] [--dry-run]"
user-invocable: true
---

# /gku:init — give this repository a CLAUDE.md

`CLAUDE.md` is read at the start of every session in a repository. It is the one place to record
how to build the project, how to test it, and the handful of rules that are actually violated
here. This skill writes it, and can refresh the shared part later without touching your own.

Run it once per repository, and again whenever the family rules improve.

## Arguments

- `--family <name>` — force the family: `moodle-plugin`, `php-app`, `cms`, `python-app`.
  Normally detected.
- `--refresh` — update the managed block in an existing file, leaving everything else alone.
- `--dry-run` — show what would be written; change nothing.

## How the file is structured

Two parts, and the distinction is the whole point:

```markdown
# <Project> — notes for Claude

...your own sections: what this project is, its quirks,
   anything you want said every session...

<!-- toolkit:begin family-rules -->
...maintained by /gku:init — replaced wholesale on --refresh...
<!-- toolkit:end family-rules -->

...more of your own sections if you like...
```

**Never edit inside the markers** — a refresh overwrites it. **Never let a refresh touch
anything outside them** — that is someone's work.

## Step 1 — Profile the repository

Read `.claude/repo-profile.json`, or detect and cache it per `reference/repo-profile.md`. You
need: family, language and version, base branch, install / lint / test / build commands, the
execution environment, the runtime surface, and whether there is a database.

**Take the family from the profile** (`reference/repo-profile.md` detects it) and map it to a
template. The two vocabularies are not identical — the profile distinguishes cases that share a
template — so map explicitly rather than assuming the names line up:

| Profile family | Template | Note |
|---|---|---|
| `moodle-plugin` | `moodle-plugin` | |
| `cms` | `cms` | |
| `php-app` | `php-app` | |
| `php-library` | `php-app` | Skip its request-handling sections; the style and bulk-write rules still apply |
| `python-app` | `python-app` | |
| `node` | — | No template yet. Write the commands section, skip the family block, and say so |
| `other` | — | Same: commands only, and name what it is |

`--family` overrides the mapping and takes a **template** name, not a profile family.

None of them fitting is a real answer: say so, write the commands section, and skip the family
block rather than forcing a bad match.

## Step 2 — Read what is already there before writing anything

**If there is no `CLAUDE.md`, go to step 3.** Otherwise **read the existing file first and
judge it** — do not assume a rewrite is wanted. Someone wrote it, and it may already be right.

Check it against what you would produce:

- **Are the commands still true?** Compare each against the profile, and against the repository
  as it is now. A command that no longer exists is the most damaging kind of staleness, because
  it will be tried.
- **Is the family block present, and does it match the current template?** Diff it.
- **Is anything in it contradicted by the code?** A rule saying output is escaped automatically,
  in a project whose templates do not escape, is worse than no file at all.
- **Is anything important missing** that the family block would add?

Then report one of three outcomes, and **do not write without saying which**:

- **Already fine** — commands correct, family block current, nothing contradicted. Say so in one
  line and stop. This is a real and common result; churning a good file is not an improvement.
- **Needs a refresh** — the family block is out of date or missing. Show what would change and
  ask before writing. With `--refresh` the user has already answered; proceed and report the
  diff.
- **Needs attention you should not apply yourself** — a stale command, or a claim the code
  contradicts. List these as findings for the developer. Correcting a factual claim about the
  project is not a mechanical edit.

Two structural cases:

- **`CLAUDE.md` without the markers** → **never overwrite it.** Show the family block and ask
  whether to insert it, and where. A hand-written file is someone's work.
- **Both `CLAUDE.md` and `AGENTS.md` hold real content** → do not reconcile them silently. If
  identical, say so and propose step 5. If they differ, show the difference and ask which is
  authoritative; two divergent copies mean nobody knows which is true, and picking one for them
  is a decision, not a tidy-up.

## Step 3 — Write it

Take the family file from `templates/<family>.md` **inside this plugin directory** (a sibling
of `skills/` and `reference/`, so it ships with the plugin and is present however it was
installed). Extract everything between the `<!-- toolkit:begin family-rules -->` and
`<!-- toolkit:end family-rules -->` **HTML comments** — match the comment form, not the bare
words, which also appear in the template's own prose. Then assemble:

```markdown
# <Repository name> — notes for Claude

<One or two sentences: what this project is, and anything structural a newcomer would get wrong.
For a Moodle plugin, that the repo root is the plugin root and it cannot run standalone.>

## Commands

| What | Command |
|---|---|
| Install | `<profile.install>` |
| Test | `<profile.test>` |
| Lint | `<profile.lint>` |
| Build | `<profile.build>` |
| Run | `<profile.runtime.how>` |

<If exec.kind is compose or image, say that these run inside the container and why — the
project targets a specific version and the host's may differ. If it fell back to host, say
that, and name the version mismatch if there is one.>

<!-- toolkit:begin family-rules -->
<the family block, verbatim>
<!-- toolkit:end family-rules -->

## This project specifically

<Anything true here and nowhere else. Leave a short prompt list if you cannot fill it in:
where configuration and credentials live, which directories are generated, what must never be
edited by hand, the deployment step, known sharp edges.>
```

**A `null` command is written as "none" with a word of why** — "no test command: this repository
has no test suite" — never invented. A made-up command is worse than an absent one, because the
next reader will try it.

**Do not pad.** This file is loaded into every session in this repository; length is a running
cost. If a rule is generic enough that any competent developer already follows it, leave it out.
What earns its place is what is specific, or what is genuinely easy to get wrong here.

## Step 4 — Fill in what only this repository knows

The template cannot know these, and they are the highest-value lines in the file. Look, then
write what you find:

- **Does the template layer escape automatically?** Find out before writing the rule — read a
  view and the render path. Stating it backwards is worse than omitting it, because a reviewer
  will trust it. If you cannot tell, say so in the file and mark it to be confirmed.
- **Is there a CSRF helper?** Name it, or record that there is none and that forms need one.
- **How is authorisation actually checked** in this codebase — a middleware, a base controller,
  a per-action call?
- **Which files hold credentials**, and are they ignored by git? Say where they live; never
  quote their contents.
- **What is generated** and must not be hand-edited — build output, compiled assets, vendor
  directories.
- **What breaks only in production** — a cache to clear, a version to bump, a migration to run.

## Step 5 — Point `AGENTS.md` at it

`CLAUDE.md` is the file this toolkit maintains, but `AGENTS.md` is what several other coding
agents look for. Rather than keeping two copies that drift, leave a pointer.

**Write `AGENTS.md` as a stub**, not a copy:

```markdown
# Agent instructions

See [CLAUDE.md](CLAUDE.md) — the conventions, commands and rules for this repository live there
and are maintained in one place.
```

**Use a stub file, not a symbolic link.** A symlink is tempting and works on macOS and Linux,
but on Windows git checks it out as a **plain text file containing the literal path** unless
symlinks are enabled — so `AGENTS.md` silently becomes a one-line file reading `CLAUDE.md`, with
no error anywhere. A stub is portable and reads correctly whatever checked it out.

Rules for this step:

- **Never overwrite an `AGENTS.md` that has real content.** If it holds actual rules, that is
  the conflict from step 2 and needs the developer's decision first.
- **An existing stub is left alone** — do not rewrite it to match wording.
- If the repository already treats `AGENTS.md` as authoritative and `CLAUDE.md` as the pointer,
  **leave that arrangement as it is.** It is the same idea in the other direction, and flipping
  it gains nothing.

## Step 6 — Report

Say which family was detected and why, the absolute path written, whether `AGENTS.md` was
created or left alone, which commands came out `null` — and, when the profile was detected in
this run rather than read, the commands it stored (see `reference/untrusted-input.md`). If
step 4 left anything unresolved, list it as a question rather than a guess.

When step 2 found the file already fine, that is the whole report — one line, no diff, no file
written.

With `--dry-run`, print the file and write nothing.

## Rules

- **Only ever write `CLAUDE.md` and a stub `AGENTS.md`.** No source files, no configuration,
  no commits.
- **Never overwrite outside the markers.** An existing hand-written file is asked about, not
  replaced.
- **Never invent a command.** Detected or `none`, with the reason.
- **Never copy secrets into the file** — describe where configuration lives, never what is in it.
- **Keep it short.** Under ~120 lines including the family block. If it is growing past that,
  the surplus belongs in the repository's own documentation, which is read on demand rather than
  every session.
- **English or Ukrainian**, matching the repository's existing documentation.

## Edge cases

- **Monorepo with several projects** — write for the repository root, and note which
  sub-directory each command applies to. Do not write one file per package.
- **The repository already has a good `CONTRIBUTING.md`** — do not restate it. `CLAUDE.md` is
  for what a session needs to know; link the rest.
- **Family detected but the template does not fit** (a Moodle plugin that is really a library,
  say) — write the commands section, include the family block, and flag the mismatch in the
  report rather than silently trimming rules.
- **An existing file that is already correct** — say so and stop. Do not reformat it, reorder
  it, or rewrite prose to match the template's phrasing; none of that is an improvement and all
  of it produces a diff someone has to read.
- **A refresh where the family block was hand-edited** — the edits are inside the markers and
  will be lost. Show what differs and ask first; if the edit is worth keeping, it belongs
  outside the markers or in the template.
