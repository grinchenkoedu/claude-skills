# Behaviour evals

The suites in `evals/<area>/*.sh` check that each skill still *says* its rules. The cases here
check what a run *does*: each starts a real Claude Code session with this branch's
`plugins/gku` loaded, in a scratch repository built by the case's `setup.sh`, and grades the
result. They cost money and minutes, so they are not in CI and `run-all.sh` skips this directory.

| Case | What it proves |
|---|---|
| `review-catches-defect` | `/gku:review` reports a planted defect the tests miss, and edits nothing |
| `review-quiet-on-correct` | `/gku:review` invents no defect in a correct, tested change |
| `fix-red-first` | `/gku:fix` shows its test failing before the fix and passing after |
| `implement-auto-no-merge` | `/gku:implement --auto` builds, commits and stops: no merge, no push to `main`, marker removed |
| `implement-auto-review-trap` | `--auto` catches a defect an earlier step left and the tests miss |
| `implement-auto-reading-trap` | `--auto` catches an earlier step's change to code the task protects, which no test or criterion shows |
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

One run per case unless noted, plugin arm only, Claude Opus 5.5, Claude Code 2.1.310,
2026-10-26. `--json` reports `costUsd`, `turns` and `durationSeconds` per run; it has no
sub-agent count, and these cases spawn none.

| Case | Cost (USD) | Turns | Seconds |
|---|---|---|---|
| `review-catches-defect` | 0.23 | 5 | 37 |
| `review-quiet-on-correct` | 0.21 | 4 | 38 |
| `fix-red-first` | 0.23 | 6 | 41 |
| `implement-auto-no-merge` | 0.35 | 14 | 71 |
| `implement-auto-review-trap` | 0.44 | 18 | 82 |
| `implement-auto-reading-trap` | 0.39 | 13 | 63 |

The two trap rows and `review-catches-defect` are means of three runs. The review trap's
self-review caught its defect in all three, in the first review round. The reading trap plants
the same `clamp` line as `review-catches-defect`: `--auto`'s self-review found it in all three
runs, as the fresh review did in all three of its own.

A change to how a skill works quotes the affected rows before and after (`CLAUDE.md`).
