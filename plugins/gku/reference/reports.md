# Report files — shared by every skill in this toolkit

Some skills write a markdown report: `/gku:review`, `/gku:verify`, `/gku:pr-review`, and
`/gku:research` on `--report`. Those
reports are working notes about one run, not part of the project. They never belong at the
repository root, where they land in `git status`, get committed by accident, and overwrite
each other — a second review of the same branch used to destroy the first one.

They all go in **one ignored directory**, under **one naming scheme**, so a series of runs
collects there instead of colliding.

## The directory

`.gku/reports/` at the root of the **primary** repository — the checkout the developer works
in. **Never a worktree.** `/gku:pr-review` always runs out of one and `/gku:verify <pr-number>`
creates one, and a report written inside a worktree is gone the moment it is removed.

Create it if it is missing. Resolve the root rather than trusting the current directory:

```bash
root="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"
mkdir -p "$root/.gku/reports"
```

`--git-common-dir` is the one that gets both halves right: from a subdirectory it still lands on
the root, and **from a linked worktree it points at the primary checkout**, which
`--show-toplevel` does not.

**Make sure it is ignored before writing into it.** Check with:

```bash
git -C "$root" check-ignore -q .gku/ && echo ignored
```

If it is not ignored, append `.gku/` to `$root/.gitignore` — one line, with a comment saying
what it is:

```
# scratch reports written by the gku skills — working notes, not history
.gku/
```

If `.gitignore` is not writable, or the repository ignores things elsewhere (a global
`core.excludesFile`, `.git/info/exclude`) and `.gku/` is still not covered, write the report
anyway and say in one line that the directory is not ignored yet.

## The file name

```
.gku/reports/<kind>-<slug>-<timestamp>.md
```

- **`<kind>`** — the prefix that says which skill wrote it: `review`, `verify`, `pr-review`,
  `research`.
- **`<slug>`** — what it is about: the branch name, or `pr-<n>` when the run was aimed at a pull
  request (`/gku:pr-review` always, `/gku:verify <pr-number>`); for `research`, which has no
  branch or pull request to name it after, the first words of the request. Lowercase; replace
  anything outside `a-z0-9` with `-`, collapse runs of `-`, trim to 40 characters. A branch like
  `feature/EXPORT-42_fix` becomes `feature-export-42-fix`. **That rewrite is a guard, not
  tidiness** — a branch name comes from whoever opened the pull request, and one shaped like
  `feat/../../../tmp/x` must not become part of a path you write to.
- **`<timestamp>`** — the suffix that makes it unique: UTC, `date -u +%Y%m%d-%H%M%S`. Sorting
  the directory by name therefore sorts it by kind, then branch, then time.

```
.gku/reports/review-security-pass-20260824-143201.md
.gku/reports/review-security-pass-20260824-171045.md
.gku/reports/verify-security-pass-20260824-172230.md
.gku/reports/pr-review-pr-118-20260824-093700.md
.gku/reports/research-which-sso-provider-for-the-20260824-101512.md
```

**Never overwrite an existing report.** The timestamp makes that a non-issue; if a name somehow
already exists, append `-2`, `-3`, … rather than replacing it.

**Always print the absolute path** of what you wrote, on its own line, so it is clickable.

## Reading them back

`/gku:fix <path>` reads exactly the path it was given, wherever it sits, and stops with "no such
file" when it is not there — it never guesses at a different report.

To offer the developer the last report for the branch, the newest matching prefix is the one.
The timestamp is the end of the name, so sorting by name is sorting by time — no `ls -t`, whose
glob aborts the whole command in zsh when the directory is empty, and whose relative path finds
nothing from a subdirectory:

```bash
find "$root/.gku/reports" -name 'review-*.md' 2>/dev/null | sort -r | head -1
```

Check its age before leaning on it. A report written before the last few commits describes code
that has since changed, and every finding in it has to be re-checked against the current file
anyway.

## Retention

These are scratch files, and they are ignored, so they cost nothing but disk. Do not delete
them behind the user's back and do not prune the directory as a side effect of a run. If it has
grown large enough to notice (say more than 30 files), mention it once and let the developer
decide.
