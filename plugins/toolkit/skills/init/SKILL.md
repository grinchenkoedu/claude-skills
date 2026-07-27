---
name: init
description: Write or refresh this repository's CLAUDE.md — detected build, test and run commands plus the conventions and security rules for its family (Moodle plugin, PHP app, CMS, Python). Regenerating replaces only a marked block, so anything written by hand survives.
argument-hint: "[--family <name>] [--refresh] [--dry-run]"
user-invocable: true
---

# /init — give this repository a CLAUDE.md

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
...maintained by /init — replaced wholesale on --refresh...
<!-- toolkit:end family-rules -->

...more of your own sections if you like...
```

**Never edit inside the markers** — a refresh overwrites it. **Never let a refresh touch
anything outside them** — that is someone's work.

## Step 1 — Profile the repository

Read `.claude/repo-profile.json`, or detect and cache it per `reference/repo-profile.md`. You
need: family, language and version, base branch, install / lint / test / build commands, the
execution environment, the runtime surface, and whether there is a database.

**Detect the family** from the profile, or from the markers directly:

| Signal | Family |
|---|---|
| `version.php` with `$plugin->component`, plus `db/` and `lang/` | `moodle-plugin` |
| `wp-content/`, `style.css` with a theme header, `functions.php`, WordPress dependencies | `cms` |
| `composer.json` with an application or library layout | `php-app` |
| `requirements.txt` / `pyproject.toml` | `python-app` |

None of them fitting is a real answer: say so, write the commands section, and skip the family
block rather than forcing a bad match.

## Step 2 — Check what is already there

- **No `CLAUDE.md`** → write a new one (step 3).
- **`CLAUDE.md` with the markers** → this is a refresh: replace only the block.
- **`CLAUDE.md` without the markers** → **do not overwrite it.** Show the family block and ask
  where to insert it, or offer to append it at the end. Someone wrote that file by hand.
- **Both `CLAUDE.md` and `AGENTS.md` exist** → compare them. If they are identical, say so and
  ask which should be authoritative before writing; maintaining two copies of the same rules
  guarantees they drift and then nobody knows which one is true. If they differ, do not
  reconcile them silently — show the difference.

## Step 3 — Write it

Take the family file from `templates/<family>.md` in this plugin, extract the content between
its markers, and assemble:

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

## Step 5 — Report

Say which family was detected and why, the absolute path written, and which commands came out
`null`. If step 4 left anything unresolved, list it as a question rather than a guess.

With `--dry-run`, print the file and write nothing.

## Rules

- **Only ever write `CLAUDE.md`.** No source files, no configuration, no commits.
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
- **A refresh where the family block was hand-edited** — the edits are inside the markers and
  will be lost. Show what differs and ask first; if the edit is worth keeping, it belongs
  outside the markers or in the template.
