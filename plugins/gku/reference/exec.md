# Where commands run — read by every skill at its first step

Short on purpose, so a skill run on its own behaves like one run after the others. How the values
get into the profile is `reference/repo-profile.md`; this is how to use them.

## The rule

**Anything that needs the project's language or its dependencies goes through the profile's
`exec.prefix`.** The stored `install`, `lint`, `test`, `testScoped`, `build` and `runtime.how`
already carry it; anything composed on the fly — a one-file lint, a query, a probe script — gets
it too. A bare `php` or `pytest` for one quick check is how a run tests the wrong version.

| Through `exec.prefix` (the container) | On the host |
|---|---|
| `composer`, `npm`, `pip` — installing dependencies | `git` — status, diff, branches, worktrees, commits |
| `php`, `python`, `node` — including a single-file lint | `gh` — pull requests, comments, replies |
| the test runner — full or scoped | reading and editing files |
| the project's CLI entry point (`./run`, `cli/*.php`, `main.py`) | HTTP requests to a published port (`localhost:<port>`) |
| database queries and one-off read-only scripts | `docker` itself, obviously |

## Host fallback

`exec.kind: host` means no container was proven; `exec.note` says why. Every reported result —
tests, lint, a probe — then says so and names the versions used where they differ from the
project's target. "Passed" against the wrong runtime is a claim the run cannot back.

## Timeouts

Wrap the test command and anything that drives the runtime in the profile's `timeoutTool`. A
hang is a failure; capture what it was doing. When `timeoutTool` is `null`, run the command and
say the hang cannot be bounded — never drop the bound silently.

## Worktrees

A compose service mounts the **primary** checkout. Run through it from a worktree — the one
`/gku:pr-review`, `/gku:verify <n>` and `/gku:pr-resolve` add — and it exercises the wrong tree
while printing something that looks like a result. Two honest routes: with `exec.kind: image`,
mount the worktree instead (`-v "<worktree>":/app`); with `compose`, check the commit out in the
primary checkout, note the branch that was there, and restore it before finishing, whatever
happened in between. Neither possible → `[unverified]`, in those words. A static read needs none
of this.

## Someone else's tree

`/gku:verify <n>` and `/gku:pr-resolve` run a test or lint command over a tree the developer did
not write. In a container the blast radius is the container; on `exec.kind: host` it is the
developer's machine and credentials — say so and ask first (`reference/untrusted-input.md`).
