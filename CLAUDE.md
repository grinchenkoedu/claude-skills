# claude-skills — notes for Claude

A Claude Code plugin, not an application: eleven skills as markdown under `plugins/gku/skills/`,
shared rules under `plugins/gku/reference/`, three agents, five shell scripts (three hooks under
`plugins/gku/scripts/`, two helpers under `plugins/gku/bin/`), and eval suites that assert the
skills still say what they claim. Nothing here runs a product — the "runtime" is a Claude Code
session that has the plugin installed.

## Commands

| What | Command |
|---|---|
| Install | none — no dependency manifest exists |
| Test | `bash evals/run-all.sh` |
| Lint | `docker run --rm -v "${PWD}":/mnt -w /mnt koalaman/shellcheck:stable --severity=warning <file>` |
| Build | none |
| Run | none locally; `claude plugin validate .` is the closest thing to loading it |

These run on the host (`exec.kind: host`): there is no container for the project itself, and
the lint command reaches for one only because shellcheck is not installed here. **There is no
timeout tool on this machine** (`timeoutTool: null`), so a hang cannot be bounded
automatically — say so rather than dropping the bound silently.

<!-- toolkit:begin family-rules -->
No family template applies: the profile's family is `other`, and the four templates under
`plugins/gku/templates/` are rules this toolkit writes into *other* projects' `CLAUDE.md`, not
rules for this repository. Do not edit them to change how a skill behaves.
<!-- toolkit:end family-rules -->

## This project specifically

- **A change to a `SKILL.md` or to `reference/` is code that runs in every session on every
  machine that updates the plugin.** Review it as such. `reference/exec.md` is read at the first
  step of every skill that runs a command, so its length is paid on every run — keep it short.
- **`scripts/second-opinion-offer.sh` runs on every prompt, every stop and every skill call in
  every session the plugin is installed in** — `hooks/hooks.json` wires it there, not only in
  gku runs. That makes it the hottest path in the plugin, hotter than `reference/exec.md`: the
  cheap gate comes first, the common case exits 0 silently and fast, and `evals/hooks/` asserts
  every event it must stay silent on. `scripts/review-report.sh` is scoped: `SubagentStop`
  with the `gku:reviewer` matcher, so it runs only when that reviewer stops. `scripts/guard.sh`
  is not in `hooks.json` at all: the `hooks:` block in the frontmatter of each skill that
  writes wires it, so it runs only inside those skills.
- **One eval suite per rule**, at `evals/<area>/<name>.sh`: each prints one summary line and
  exits non-zero the moment its rule stops holding. Adding a convention to a skill means adding
  or extending a suite; `bash evals/run-all.sh` runs them all and CI runs the same command.
- **The suites check what a skill says; `evals/live/` checks what a run does.** Those cases run
  real sessions on your credential, so they stay out of CI and `run-all.sh` skips them;
  `evals/live/README.md` has the command, the costs, and the macOS `git` trap to clear first. A
  pull request that changes how a skill works quotes the affected cases' cost, turns and
  seconds before and after — "economical" is a claim the README makes, and this is what backs
  it. The two user-facing READMEs quote no prices: one run on one model reads as a promise.
- **Prose wraps at the file's width** (about 96 characters; a command or a table row that
  cannot be broken is left long). The two READMEs are English and
  Ukrainian and must stay in step — `evals/docs/readme.sh` asserts that both describe every
  mechanic, and it can only check tokens identical in both languages.
- **`${CLAUDE_PLUGIN_ROOT}` expands in a `hooks:` block and in `allowed-tools`, nowhere else.**
  It is not set in the shell a skill's commands run in. A script a skill needs to *run* belongs
  in `plugins/gku/bin/`, which Claude Code puts on `PATH`; `plugins/gku/scripts/` is for what the
  harness resolves itself, like the guard the hooks name.
- **`allowed-tools` is a whitelist**, not an addition: a skill that lists one tool has only that
  tool.
- **An injected `` !`command` `` line runs before the skill does** and its output lands in the
  prompt. Keep it cheap, end it in `|| true`, and add one only where the skill always reads it.
- **Effort pins live in `plugins/gku/agents/*.md`, never in a skill's frontmatter.** An agent
  starts its own conversation, so its pin is free; a skill runs inside the session's, and a
  changed effort invalidates the cached messages on the way in and on the way back.
  `evals/agents/effort.sh` asserts it; the reviewer's pin follows the rows in
  `evals/live/README.md`, not the rule of thumb that suggested them.
- **Record a `Ruling:` line** in the commit body when you decide something the plan did not:
  what, why, and what it costs if wrong. `/gku:review` reads them back.
- **The plugin manifest has no `version`, on purpose.** Claude Code then treats every commit as
  a new version, so `/plugin marketplace update` always brings the latest; a declared version
  would hold users on whatever was last bumped. Both READMEs explain it under "Why you always
  get updates" — do not add the field back because a validator suggests it.
- **What breaks only "in production":** the installed plugin is a cache keyed by content, so a
  session keeps running the version it was started with. A change merged to `main` is not what
  your current session executes — to exercise it, install from the branch or run with
  `--plugin-dir plugins/gku`.
