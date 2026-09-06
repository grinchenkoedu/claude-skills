# claude-skills — notes for Claude

A Claude Code plugin, not an application: eleven skills as markdown under `plugins/gku/skills/`,
shared rules under `plugins/gku/reference/`, two shell scripts, and eval suites that assert the
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

No family template applies: the profile's family is `other`, and the four templates under
`plugins/gku/templates/` are rules this toolkit writes into *other* projects' `CLAUDE.md`, not
rules for this repository. Do not edit them to change how a skill behaves.

## This project specifically

- **A change to a `SKILL.md` or to `reference/` is code that runs in every session on every
  machine that updates the plugin.** Review it as such. `reference/exec.md` is read at the first
  step of every skill that runs a command, so its length is paid on every run — keep it short.
- **One eval suite per rule**, at `evals/<area>/<name>.sh`: each prints one summary line and
  exits non-zero the moment its rule stops holding. Adding a convention to a skill means adding
  or extending a suite; `bash evals/run-all.sh` runs them all and CI runs the same command.
- **Prose wraps at the file's width** (about 96 characters). The two READMEs are English and
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
- **Record a `Ruling:` line** in the commit body when you decide something the plan did not:
  what, why, and what it costs if wrong. `/gku:review` reads them back.
- **What breaks only "in production":** the installed plugin is a cache keyed by content, so a
  session keeps running the version it was started with. A change merged to `main` is not what
  your current session executes — to exercise it, install from the branch or run with
  `--plugin-dir plugins/gku`.
