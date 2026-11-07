# Behaviour evals

The suites in `evals/<area>/*.sh` check that each skill still *says* its rules. The cases here
check what a run *does*: each starts a real Claude Code session with this branch's
`plugins/gku` loaded, in a scratch repository built by the case's `setup.sh`, and grades the
result. They cost money and minutes, so they are not in CI and `run-all.sh` skips this directory.

| Case | What it proves |
|---|---|
| `review-catches-defect` | `/gku:review` reports a planted defect the tests miss, writes the report a blocker calls for, and changes no code |
| `review-quiet-on-correct` | `/gku:review` says "Ready to push" on a correct, tested change that checks its input |
| `fix-red-first` | `/gku:fix` shows its test failing before the fix and passing after |
| `implement-auto-no-merge` | `/gku:implement --auto` builds, commits and stops: no merge, no push to `main`, marker removed |
| `implement-auto-review-trap` | `--auto` catches a defect an earlier step left and the tests miss |
| `implement-auto-reading-trap` | `--auto` catches an earlier step's change to code the task protects, which no test or criterion shows |
| `review-after-long-build` | `/gku:review` run after a build in the same session still names that change |
| `review-offers-second-opinion` | after a typed `/gku:review`, the session asks once whether the agent CLIs installed here should review the diff too, and runs none — needs `agy`, `copilot` or `opencode` on the machine; `setup.sh` stops with the reason otherwise |
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

`review-catches-defect` changed after it too. Its `writes-nothing` grader counted Write calls,
so it failed the run on `main` that wrote the blocker report with Write and missed the two that
wrote it through Bash. The new graders check that a report exists under `.gku/reports/`, that no
other file was created, and that `lib/math.sh` still has the defect. They show a regression
#53 brought: the forked reviewer on Sonnet writes the report the skill asks for in 1 run of 3
(three runs each on 2026-11-01: 0/3, then 1/3 with the rule ahead of the answer, then 1/3 with
its own step 5b), where the inline review on `main` wrote it in 3 of 3. About 0.055 USD and 21 s
a run.

The hook in `plugins/gku/hooks/hooks.json` (`scripts/review-report.sh`) closed that gap. On
2026-11-01, three runs passed 3/3 on every grader. Each reviewer stopped without a report, was
sent back once, wrote it with Write and returned the review again: step 5b alone held in none of
the three, so the hook is what holds the rule. A blocker review now costs about 0.095 USD and
37 s instead of 0.055 and 21 s. A clean one is not sent back: `review-quiet-on-correct`, one run,
"Ready to push", 0.05 USD.

The second-opinion offer (`scripts/second-opinion-offer.sh`) was first checked by hand on a
`review-catches-defect` scaffold on 2026-11-01:

- **When the offer was the fork's own closing line,** the review came back without it.
- **When it came from a `UserPromptSubmit` context,** the fork received it and the caller did
  not: a typed forked skill runs as a local command, and the main model took no turn
  (`turns 0`).
- **With the `Stop` hold,** the caller took one turn and asked, naming `agy`, `copilot` and
  `opencode` and their vendors. That was 0.126 USD and 29 s, against 0.115–0.119 without the
  offer.

`review-offers-second-opinion` now grades that last point: the run ends on the question, which
is what the session's one turn is, and the judge reads it. It rests on the agent CLIs really
installed on the machine — no stub — so it runs where `gku-agents` lists one and its `setup.sh`
stops with the reason elsewhere; like every case here it stays out of CI. One run on 2026-11-01,
with `agy`, `copilot` and `opencode` installed: 0.11 USD · 1 turn · 31 s · 1/1 — the review came
back with its blocker, the session asked once, named the three and their vendors, and the kept
trace shows no agent run — the judge reads the last message only, so that part is read by hand.
With the offer made an AskUserQuestion dialog (the prose question had gone unread in a real
session), one run on 2026-11-02: 0.17 USD · 2 turns · 29 s · 1/1 — the eval session has no
dialog tool, so it fell back to one message listing the three agents and `none`, which is what
the judge accepts in that case.

Then `reference/second-opinion.md` was run with `agy`:

- **Its first brief came back empty.** `agy` tried a command, the headless mode denied it, and
  the turn ended with no answer.
- **The brief that says commands are unavailable** returned the clamp blocker at
  `lib/math.sh:7`, which agrees with the review, in 59 s and about 50k `agy` tokens. The
  scaffold was unchanged.

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
  correct (see the line under the table); `review-catches-defect` before wrote the report the
  skill asks for on a blocker, which its old `writes-nothing` grader counted against it (see
  under the table); `fix-red-first` after has one `reports-both-lines` judge FAIL.
  `fix-red-first` and `review-after-long-build` are scored with the graders now in their case
  files, re-applied to the kept traces: the judges they replace failed a correct run on each
  side.

The reviewer's model and effort were measured on 2026-11-07, Claude Code 2.1.319, Claude
Opus 5.5 as the session's model, three runs per case, the offer suppressed (below). **Sonnet** is
`gku:reviewer` as pinned; **Opus low** is the same file with `model: inherit` and
`effort: low`, which a talk on frontier-model economics said should cost less:

| Case | Sonnet: USD · turns · s · passed | Opus low: USD · turns · s · passed |
|---|---|---|
| `review-catches-defect` | 0.067 · 0 · 23 · 3/3 | 0.140 · 0 · 28 · 3/3 |
| `review-quiet-on-correct` | 0.051 · 0 · 13 · 3/3 | 0.111 · 0 · 14 · 3/3 |
| `review-after-long-build` | 0.265 · 8 · 55 · 3/3 | 0.334 · 7 · 63 · 3/3 |

Every grader passed on both sides, so the stronger model at low effort found nothing Sonnet
missed here, and it cost about twice as much on the two review-only cases. The pin stays
`model: sonnet`; the two Haiku agents carry `effort: low`, which no case here exercises.

**The second-opinion offer gets in the way of these three cases.** With `agy`, `copilot` or
`opencode` on `PATH`, the Stop hook gives the session a turn after the review to make the offer,
so the last message is the offer and the judges that read it fail — three runs of each review
case failed that way at 0.16–0.18 USD and 2 turns before the rows above were taken. The eval
session has no dialog tool, so the offer cannot be answered either. Measure the review alone
with a `PATH` that hides the agents, the way the rows above were taken:

```bash
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin ~/.local/bin/claude plugin eval . \
  --eval-dir evals/live --case review-catches-defect --runs 3 --ablation none \
  --scaffold --allow-tools Bash Edit Write --trust-plugin --no-publish --model claude-opus-5-5
```

A change to how a skill works quotes the affected rows before and after (`CLAUDE.md`).
