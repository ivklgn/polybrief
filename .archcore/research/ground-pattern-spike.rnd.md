---
title: "Ground pattern spike: blind task-vs-system split against parallel"
status: rejected
tags:
  - "polybrief"
  - "research"
  - "source:measurement"
---

## Goal

Timeboxed probe for @.archcore/ideas/research-patterns.idea.md, step 1, `ground` only: does the blind split (`asked` sees the task, `exists` does not, a judge maps the gap) find rows that a plain `parallel` run with the same task misses? The answer decides whether a built-in `ground`, and the runtime change "material per participant" that `ground` would use, are worth planning. `hypotheses` and `audit` are not part of this spike. Timebox: one run per form, 8 runs. Date: 2026-10-15.

## Questions

1. Does `ground` raise the seeded row on each task: (a) `ALREADY`, (b) `CONFLICT`, (c) `BREAKS`, (d) nothing beyond `GAP`?
2. Does `parallel` with the task in the brief raise the same seeded rows?
3. Which true rows does `ground` raise that `parallel` misses, and the reverse?
4. How many false rows does each form raise on the clean task (d)?
5. What does a `ground` run cost in seconds and input tokens compared with `parallel`?

## Findings

### Setup

- polybrief 0.0.2 (installed binary). Workers: codex `gpt-6-sol`, Claude Code on its default model. One run per form, all 8 runs `RESULT complete`, no `malformed` answer.
- Base tree: `git archive b3cfc5d`, made into a one-commit repository. Untracked drafts (the idea, the intent research, `run-at-base.proposal.md`) were not visible to workers.
- Seeded tasks:
  - (a) preview a pattern and list the built-ins. `polybrief plan` and `polybrief patterns` already do this. A per-stage token estimate is new work.
  - (b) a settings file at `~/.config/polybrief/config.toml`. This goes against @.archcore/architecture/arguments-only-runtime.adr.md.
  - (c) name checklists by a front-matter `name:`. This changes basename naming and the refusal `two checklists named` (`main.go:215-222`).
  - (d) `polybrief patterns --names`, clean.
- `ground`: the pattern from the idea, with `asked` on claude and `exists` on codex. The judge (claude) and `asked` get the task as checklist `task` (`with task`), using the wrapper workaround from @.archcore/research/intent-pattern-experiment.research.md, Finding 8. The shared brief names only the area of the code, never the task.
- `parallel`: the same area text, plus the task inline and the same five row types (`ALREADY`, `GAP`, `CONFLICT`, `BREAKS`, `UNCLEAR`). It also has the instruction to open cited files and decisions before a `CONFLICT` or `BREAKS` row.
- Spike materials (tasks, briefs, `ground.md`, run outputs) live in the temporary session scratchpad `/private/tmp/claude-501/-Users-ivklgn-Documents-github-swarm/a6476b78-5d79-4e8d-8d29-6b474decbc46/scratchpad/ground/` and are not kept. No spike code went into the repository.

### Results

| Task | Form | already | gap | conflict | breaks | unclear | wall s | input tokens |
|---|---|---|---|---|---|---|---|---|
| a | ground | 9 | 6 | 0 | 3 | 8 | 134 | 513,615 |
| a | parallel codex / claude | 4 / 4 | 3 / 1 | 0 / 2 | 0 / 1 | 3 / 2 | 76 | 406,119 |
| b | ground | 8 | 5 | 1 | 3 | 7 | 137 | 520,198 |
| b | parallel codex / claude | 5 / 5 | 2 / 2 | 3 / 3 | 2 / 4 | 3 / 3 | 75 | 548,314 |
| c | ground | 12 | 2 | 1 | 4 | 5 | 128 | 436,982 |
| c | parallel codex / claude | 3 / 3 | 2 / 2 | 2 / 4 | 2 / 2 | 1 / 4 | 74 | 391,262 |
| d | ground | 10 | 8 | 0 | 1 | 5 | 104 | 356,723 |
| d | parallel codex / claude | 2 / 2 | 2 / 2 | 1 / 1 | 0 / 0 | 0 / 0 | 65 | 269,909 |

Counts are the `SUMMARY` lines. Wall time is from `time -p` around the whole command. Input tokens are the launcher's `TOKENS` lines summed over the calls of one run, cached tokens included.

- **Finding 1 (Q1): `ground` raised every seeded row.**
  - (a) `ALREADY` for the preview and the list (`runner.go:264-273`, `runner.go:187-194`). `GAP` for the token estimate.
  - (b) `CONFLICT` with `arguments-only-runtime.adr.md:15,24` and `polybrief-config.spec.md:11,54`. The judge added that the change needs a superseding decision record.
  - (c) `BREAKS` at `main.go:215` and `main.go:220-222` and in both specs. It also found `CONFLICT` with `go-runtime.adr.md:24`, which was not seeded and is true.
  - (d) no `CONFLICT`. One `BREAKS` row: `patterns` accepts no flags today (`main.go:85,97-104`). This is a true contract extension, not a defect.
- **Finding 2 (Q2): `parallel` raised the same seeded rows, on both workers, on every task.**
  - (a) both workers: `ALREADY` for preview and list.
  - (b) both workers: `CONFLICT` with the arguments-only ADR.
  - (c) both workers: `CONFLICT` with the CLI and pattern-file specs, plus `BREAKS` at `main.go:215-216`. Claude also cited `go-runtime.adr.md:24`.
  - On (a), claude in `parallel` also found the runner spec rule "MUST print only the `PLAN` and `CALLS` lines" (`polybrief-pattern-runner.spec.md:61`). `ground` found the same rule as a `BREAKS` row.
- **Finding 3 (Q3): each form raised some true rows the other missed.**
  - Only `ground`, (d): list mode runs `--show-config` first (`runner.go:155-166`), so a broken setting would make completion print nothing.
  - Only `ground`, (b): `XDG_CONFIG_HOME` handling (`config.go:58`).
  - Only `parallel`, (b): the location reopens the rejected @.archcore/architecture/polybrief-home.adr.md. The `ground` judge wrote "I did not open the file".
  - Only `parallel`, (c), both workers: a `name:` value outside `a-z0-9-` (for example a namespaced `kit:review-tests`) would now be refused (`main.go:216-218`).
  - Only `parallel`, (c), claude: the reading "use `name:` only to resolve a clash", which avoids the breaks.
  - The blind split did not produce a class of rows that `parallel` lacked. Both forms found the "the task conflicts with a recorded decision" rows that the idea expected only from `ground`.
- **Finding 4 (Q4): neither form raised a clearly false row on the clean task (d).**
  - `ground` gave 10 `ALREADY` rows that restate invariants ("exit code stays 0", "existing checks still pass"), plus 5 `UNCLEAR` rows, 2 of them useful (order of names, config failure).
  - `parallel` gave one true `CONFLICT` per worker (the CLI spec needs amending for `--names`) and nothing else.
  - Across all four tasks, `ground` produced 24–27 rows per run. A `parallel` worker produced 5–17. Most of the difference is `ALREADY` restatements.
- **Finding 5 (Q5): cost.**
  - Wall time: `ground` 104–137 s against `parallel` 65–76 s, about 1.7×, because the judge is a second sequential stage.
  - Input tokens: 0.95–1.32× `parallel`. `exists` on codex was the largest call (218k–319k).
  - The cost is in range of an `intent` form (97–159 s, 172k–292k) from the intent research, Finding 7.
- **Finding 6: limits of this probe.**
  - One run per form, so run-to-run variance is not measured.
  - All four tasks touch areas with dense accepted specs and ADRs under `.archcore/`. A single reader that was told to check recorded decisions found the conflicts easily there. A repository with fewer recorded decisions could favor `ground`. Not tested.
  - Vendor and role are confounded: `exists` ran only on codex, and roles were not swapped.
  - The seeded tasks were written by the experimenter, who knew the conflicts.
- **Finding 7: probe outcome.**
  - On these four tasks, the blind split added no seeded or decision-level row over `parallel` with a structured brief. It cost about 1.7× the wall time and produced longer lists.
  - The value the idea expected from `ground` came from the row format (`ALREADY` / `GAP` / `CONFLICT` / `BREAKS` / `UNCLEAR`) plus the instruction to check recorded decisions, not from blindness.
  - That row format needs no polybrief change. It is a brief the caller writes for `parallel`.
- **Finding 8: revised Δ handed to the conductor.**
  - `ground` gives no reason to change the built-in pattern set or to add the material channel (`-m`, `given`): modifies=[], decision=none, creates=[].
  - `hypotheses` does not use the material channel: its brief lists both hypotheses for every worker, and `{{role}}` selects which one a worker tests (`runner.go:768-773`). It runs on the current runtime as a pattern file.
  - The material channel has one consumer outside this idea: the ivklgn-kit intent pass. Its spec (`polybrief-integration.spec.md`, clause 10, commit `d116797`) passes the task as a `-c` file to a built-in `intent`, which polybrief 0.0.2 does not ship. The channel question belongs to `intent` and @.archcore/architecture/run-at-base.adr.md.
  - Bug cases for a `hypotheses` spike: `1c044aa` here, ivklgn-kit `591e1b6` (local Git, with a test), and the seeded `install.sh:43` defect of the intent research. `38776e4` is Windows-only and cannot be told apart by running it on macOS.
  - `audit` and `hypotheses` remain candidate follow-up spikes, not committed work.
