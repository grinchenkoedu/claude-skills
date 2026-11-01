# Behaviour evals

The suites in `evals/<area>/*.sh` check that each skill still *says* its rules. The cases here
check what a run *does*: each starts a real Claude Code session with this branch's
`plugins/gku` loaded, in a scratch repository built by the case's `setup.sh`, and grades the
result. They cost money and minutes, so they are not in CI and `run-all.sh` skips this directory.

| Case | What it proves |
|---|---|
| `review-catches-defect` | `/gku:review` reports a planted defect the tests miss, and edits nothing |
| `review-quiet-on-correct` | `/gku:review` says "Ready to push" on a correct, tested change that checks its input |
| `fix-red-first` | `/gku:fix` shows its test failing before the fix and passing after |
| `implement-auto-no-merge` | `/gku:implement --auto` builds, commits and stops: no merge, no push to `main`, marker removed |
| `implement-auto-review-trap` | `--auto` catches a defect an earlier step left and the tests miss |
| `implement-auto-reading-trap` | `--auto` catches an earlier step's change to code the task protects, which no test or criterion shows |
| `review-after-long-build` | `/gku:review` run after a build in the same session still names that change |
| `probe` | the agent can run `git` in the sandbox — run it first on a new machine |

## Running them

From the repository root, one case per command — a repeated `--case` keeps only the last one:

```bash
claude plugin eval . --eval-dir evals/live --case review-catches-defect --runs 1 --ablation none \
  --scaffold --allow-tools Bash Edit Write --trust-plugin --no-publish
```

- `--scaffold` runs the case's `setup.sh`; without it the agent starts in an empty directory.
- `--allow-tools Bash Edit Write`: without Bash, the "never runs X" graders pass for nothing.
- `--no-publish`: the HTML report is otherwise published to claude.ai.
- `--keep-temp` keeps each run's `trace.jsonl` — read it before trusting a pass that looks cheap.
- `--ablation with-without` adds a no-plugin arm; drop `--runs 1` for three runs and a variance.
- The target is the repository root on purpose: a case may only load plugins under the directory
  the run targets, and cases kept under `plugins/gku/` would ship in every user's cache.

## macOS: the sandbox cannot run Apple's git

Inside the eval sandbox `/usr/bin/git` exits 72 — the xcrun shim cannot write its cache — and
a `PATH` search skips any git it is not allowed to stat, which is every Homebrew path and every
directory under your home. Running a binary by its absolute path works. On Apple silicon the
way round is a wrapper in `/usr/local/bin`, the one readable directory ahead of `/usr/bin`:

```bash
brew install git
sudo sh -c 'printf "#!/bin/sh\nexec /opt/homebrew/bin/git \"\$@\"\n" > /usr/local/bin/git && chmod 755 /usr/local/bin/git'
```

That makes Homebrew's git your default everywhere; `sudo rm /usr/local/bin/git` undoes it. The
`probe` case passes once it works. **Not on an Intel Mac:** there Homebrew itself lives in
`/usr/local`, the line would overwrite its own `git` link with a wrapper calling a path that
does not exist, and git would stop working — run `probe` first and find the way round from what
it prints. `/usr/bin/python3` is the same kind of shim, which is why
the fixture project is plain bash.

## Costs

Three runs per case, plugin arm only, Claude Opus 5.5 as the session's model, Claude Code
2.1.316, 2026-11-01. **Before** is `main` at `1203271`, where every review ran inline in the
session; **after** is the plugin with its own agents, where `/gku:review` forks onto
`gku:reviewer` (Sonnet) and `--auto` dispatches it each round. Both sides ran this branch's case
files, `Agent` granted in every case. `--json` reports `costUsd`, `turns` and
`durationSeconds` per run; the traces show `costUsd` includes the sub-agents' spend, while
`turns` counts the main session only — a forked `/gku:review` shows 0.

| Case | Before: USD · turns · s · passed | After: USD · turns · s · passed |
|---|---|---|
| `review-catches-defect` | 0.25 · 6 · 38 · 2/3 | 0.06 · 0 · 22 · 3/3 |
| `review-quiet-on-correct` | 0.22 · 5 · 47 · 1/3 | 0.05 · 0 · 24 · 2/3 |
| `fix-red-first` | 0.23 · 7 · 31 · 3/3 | 0.23 · 7 · 32 · 2/3 |
| `implement-auto-no-merge` | 0.38 · 14 · 64 · 3/3 | 0.40 · 10 · 76 · 3/3 |
| `implement-auto-review-trap` | 0.45 · 17 · 88 · 3/3 | 0.48 · 14 · 90 · 3/3 |
| `implement-auto-reading-trap` | 0.41 · 16 · 66 · 3/3 | 0.62 · 18 · 136 · 3/3 |
| `review-after-long-build` | 0.31 · 12 · 51 · 3/3 | 0.23 · 7 · 49 · 3/3 |

`review-quiet-on-correct` changed after this table: its `percent` fed unvalidated arguments to
`$(( ))`, which the checklist rates a WARNING, so the reviews that said so were right. With the
function validating its input and the verdict graded by regex, three runs on 2026-11-01:
0.06 USD · 0 turns · 15 s · 3/3, nits only.

What the rows say, and what they do not:

- **A review on its own costs about a quarter.** Most of that is the model: the fork runs on
  Sonnet where the session ran Opus. A session already on Sonnet saves less.
- **A review after a build** leaves the building session lighter: its own share fell from 0.31
  to 0.17 and from 12 turns to 7, with the review's 0.06 on Sonnet beside it.
- **`--auto` costs the same or more.** The reviewer reads the branch fresh each round, and when it
  finds something a fix round needs another review: in two of the reading trap's three runs it
  ran twice, which is the 0.62 and the doubled seconds.
- **Every case caught its defect on both sides.** No case here shows the fresh reviewer catching
  what the inline review missed; the gain measured is context and cost, not catches.
- The failures are graders and variance, both sides: `review-quiet-on-correct` rated a real
  `$(( ))` injection a WARNING in 2 runs before and 1 after, against a fixture that called it
  correct (see the line under the table); `review-catches-defect` before wrote the report the skill
  asks for on a blocker, which `writes-nothing` counts against it; `fix-red-first` after has one
  `reports-both-lines` judge FAIL. `fix-red-first` and `review-after-long-build` are scored with
  the graders now in their case files, re-applied to the kept traces: the judges they replace
  failed a correct run on each side.

A change to how a skill works quotes the affected rows before and after (`CLAUDE.md`).
