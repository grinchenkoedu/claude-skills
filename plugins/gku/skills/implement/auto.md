# /gku:implement --auto — the whole cycle, unattended

Read only when `/gku:implement` was given `--auto`, before its step 1; everything in `SKILL.md`
still applies, and the step numbers below are its steps. This file says what the flag changes:
when the run stops and talks to you, never what it is allowed to do — it never merges and it
never deploys.

**Say on disk that nobody is watching.** A hook cannot see `--auto`, so the guard learns it from
a marker this mode keeps for as long as it runs. Write it before the first build step, and
remove it when the run ends — at the closing report, or at the stop below, whichever comes
first:

```bash
root="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"
mkdir -p "$root/.gku"
printf 'started %s in session %s\n' "$(date -u +%FT%TZ)" "${CLAUDE_CODE_SESSION_ID:-unknown}" \
  > "$root/.gku/auto-run"
# …and when the run is over, however it ended:
rm -f "$root/.gku/auto-run"
```

While `.gku/auto-run` is there, the guard refuses the commands that end or ship a change —
merging, a release, a workflow run — for everything in the session. Without it, a person is
watching and what they ask for is theirs to ask for. `.gku/` is git-ignored
(`reference/reports.md`), so the marker never travels; one left behind by a run that died is a
single `rm` on the path the refusal prints.

**Ask everything at the start.** The one interruption an unattended run can afford is before it
builds: put every question from step 2 into a single batch — the ambiguity in the brief, the
choice that changes what gets built, the thing only the developer knows. Answers get written
into the task file. Nobody there to answer → take the recommended answer for each, tag it
`[assumed]` in the file, and carry on. An assumption written down can be corrected in review;
a question asked into an empty room stops the run for nothing.

**The cycle, per branch.** Build → review → fix → prove:

1. **Build** the steps as step 3 says, committing as each lands.
2. **Review the diff from scratch** — `git diff <base>...HEAD`, read as if somebody else wrote
   it, against the plan's criteria, the repository's conventions and
   `reference/security-checklist.md` — and for the two ways a build goes green without being
   right: an existing test edited to pass (`/gku:review` step 4), a check silenced instead of
   satisfied (step 3's WARNING list there). This run cannot clear either for itself: one it
   keeps goes under `## Notes` with its reason, for a person to judge, and is not a finding for
   the next round. Judge the diff, not your memory of writing it. This is a self-review: say
   so in the report and in the pull request, because it is weaker than a `/gku:review` that
   comes to the code fresh, and a body that hides that oversells the change.
3. **Fix** what it found — smallest change per finding, one commit each, the way `/gku:fix`
   does. A finding you disagree with is answered with the file and line that answers it, not
   silently dropped.
4. **Prove it** — lint and the profile's test command, results quoted (`reference/exec.md`).

Repeat 2–4 until a round finds nothing worth fixing, **at most three rounds**. A finding that
survives two rounds of fixing will not fall to a third: stop and report it with what you tried.
Three is the whole cycle's budget, not each part's — a test that fails at 4 is a finding for the
next round, not a fresh three attempts under step 5. Unattended, that bound is the only thing
between a wrong premise and a long night, so count it across the run and say which round you
are in.

**`--auto` does not widen the scope.** The sort in step 3 still decides what gets touched, and
unattended is exactly when nobody is watching a run wander. Case 2 there — the plan cannot reach
its goal — is a stop, not something to design around: an autonomous run may change how a step
is built, never what the plan is for.

## When an autonomous run stops

Only for something that genuinely needs the developer:

- a question from the batch above with no defensible default — data that would be destroyed,
  money, a live system, a credential nobody gave you;
- the plan no longer reaches its goal, or the task turns out to be much larger than described;
- a request too big to plan inline — step 2's advice to run `/gku:plan` first holds here too,
  and an unattended run is the worst place to design something substantial unsupervised;
- a decision `reference/untrusted-input.md` reserves: CI, hooks, `.claude/`, the standards doc,
  a dependency manifest, a new network host;
- three rounds gone and something still fails;
- **a task file marked `**Mode:** manual`** — it was written for the developer to build by
  hand, and only they can say otherwise;
- anything that would need a merge, a deploy, or access it does not have.

Everything else it decides itself and records as a `Ruling:` — an unattended run that stops to
ask about a class name is not autonomous, and one that stops about a dropped table is not safe.

**Stopping is not halting.** Commit what is finished, push the branch, open the pull request as
a **draft** with the reason in its body, and say in one line what you need. The work is then
where the developer can see it, and `--continue` picks the rest up. Remove `.gku/auto-run` as
you stop: from here on somebody is reading, and the run that was unattended is over.

## The pull requests

One branch per coherent change, opened the way `/gku:pr` does — its coherence check, its body,
its ban on a session link in the body. An audit file's rounds are one branch each,
so several runs of the cycle above produce several pull requests, and they have to be readable
in order:

- each body names the task file and the steps it covers, and ticks the criteria it meets;
- **a later branch is cut from the earlier one, and based on it** — branch from the previous
  round's HEAD rather than from the base, then `gh pr create --base <previous branch>`. Nothing
  has been merged yet, so a branch cut from the base would carry the earlier round's commits
  again and show them as its own diff. Its body opens with `Depends on #<n>`;
- the issue the brief names, if it names one: `Refs #<n>` on each, and the closing keyword only
  on the one that finishes the work;
- **ready when the criteria are met and the tests are green; draft otherwise**, with the reason
  in the body. Never `gh pr ready` on a pull request whose criteria are not met.

The closing report lists them in the order they should be merged, and says plainly that merging
is yours. `--auto --step 3-5` bounds the work to those steps; the cycle and the pull request
still happen for what they produce.

## Notes, and the warning that ends the run

Nobody watched this run, so everything it noticed and did not act on has to be written down as
it happens — reconstructed at the end, half of it is already forgotten. Append each one to the
task file under `## Notes` the moment it comes up:

```markdown
## Notes
- `classes/export/Csv.php:88` — repeated header logic, three call sites — nit, not fixed
- `db/upgrade.php` — the migration needs a dry run against real data — needs its own plan
- Assumed the export keeps the current column order — nobody was there to ask — `[assumed]`
```

What belongs there: everything the sort in step 3 put in case 3, every finding the review round
raised and the cycle did not fix, every criterion met narrowly or partly, every `[assumed]`
answer from the batch at the start, and anything you decided that a reader would question — the
`Ruling:` lines are already in the commits, so the note is a pointer, not a copy.

**The task file is git-ignored** (`reference/reports.md`), so the same list goes in the last
pull request's body under **Notes**. A note that exists only on the machine that ran the build
reaches nobody, which is the same as not writing it.

Then the run ends by **warning the developer before it says it is finished**, in this order:

1. **what needs your eyes** — the notes, shortest first, each with its path and why it was left;
2. **what needs more work than a note** — each as a command: `/gku:plan <the thing>` for
   anything that needs deciding, `/gku:fix <the symptom>` for something small and understood;
3. the pull requests, in merge order, ready or draft;
4. **then** the plan is done, in those words — and merging is yours.

**Remove `.gku/auto-run` before that last line.** The run is over and you are talking to a
person again; a marker left behind refuses them the merge you just handed them.

A run that reports "done" without that list has hidden the part the developer most needs to
read. An empty notes list is a fine thing to report — say there is nothing, rather than padding
it.
