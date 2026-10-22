---
title: "Intent baseline spike: blind split against parallel with the same row format"
status: accepted
tags:
  - "polybrief"
  - "research"
  - "source:measurement"
---

## Goal

Close the gap left by @.archcore/research/intent-pattern-experiment.research.md: the built-in `intent` was never compared with a `parallel` run that gets the task and the diff together and reports the same rows. @.archcore/research/ground-pattern-spike.rnd.md and @.archcore/research/hypotheses-audit-spike.rnd.md found that a blind or role split adds nothing over `parallel` with the row format in the brief. Does that hold for `intent`? Date: 2026-10-22.

## Questions

1. Does `parallel` with task and diff in one prompt report the seeded defect as its first `CONFLICT` row, as `intent` did?
2. Does it miss true rows that `intent` finds, or the reverse?
3. What do both forms cost in wall seconds and input tokens?

## Approach

- polybrief 0.0.3 (installed, built from `165ddf8`). Workers: codex `gpt-6-sol` at `medium`, claude `opus` at `medium`, the fixed pair of the kit's intent pass (ivklgn-kit `skills/codereview/references/intent.md`). One run per form, 8 runs, all `RESULT complete`, every call `ok`.
- Changes A and B, clean and seeded, as in the intent research: clones of this repository checked out at `1c044aa` (base `130423a`) and `5c2c5d9` (base `38776e4`), the seeded one-line edits applied in the working tree, `-b <base>` for both forms. Task texts verbatim from the research.
- `intent`: the built-in pattern with the kit's brief template and `-c task.md`. 3 calls.
- Baseline: a custom one-stage pattern `parallel-rows` (`workers: codex, claude`, `expect: ^(CONFLICT|MISSING|EXTRA|UNCLEAR|MATCH|SUMMARY)`, prompt `{{brief}}`) with `-c task.md`. The brief asks each worker to list the intended items from the task, the built items from the diff, and report the judge's row format. 2 calls, two independent answers.
- Materials and outputs lived in `$TMPDIR/intent-baseline` and are not kept.

## Findings

| Form | Pattern | first CONFLICT names the seeded defect | conflict | missing | extra | unclear | match | wall s | input tokens |
|---|---|---|---|---|---|---|---|---|---|
| A-seeded | intent (judge) | yes, `runner.go:420-422` | 3 | 1 | 9 | 1 | 13 | 96 | 220,934 |
| A-seeded | parallel codex / claude | yes / yes, `runner.go:420` | 1 / 2 | 0 / 2 | 2 / 3 | 0 / 2 | 6 / 6 | 66 | 164,152 |
| B-seeded | intent (judge) | yes, `install.sh` `[ -z "$want" ]` | 1 | 0 | 7 | 2 | 17 | 75 | 108,021 |
| B-seeded | parallel codex / claude | yes / yes, `install.sh:44` | 2 / 1 | 1 / 0 | 0 / 4 | 1 / 4 | 8 / 16 | 92 | 164,798 |
| A-clean | intent (judge) | no conflict | 0 | 3 | 8 | 2 | 12 | 97 | 270,253 |
| A-clean | parallel codex / claude | no conflict | 0 / 0 | 0 / 0 | 2 / 4 | 0 / 3 | 7 / 7 | 41 | 204,003 |
| B-clean | intent (judge) | 2 conflicts, see below | 2 | 0 | 7 | 4 | 15 | 88 | 107,201 |
| B-clean | parallel codex / claude | 3 / 2 conflicts, see below | 3 / 2 | 1 / 0 | 0 / 5 | 1 / 5 | 9 / 12 | 80 | 164,963 |

Counts are the `SUMMARY` lines; wall seconds from `date` around the command; input tokens are the `TOKENS` lines summed over the calls of one run, cached tokens included.

- Finding 1 (Q1): the baseline found both seeded defects, in all four answers (two workers, two changes), as the first `CONFLICT` row with file and line, and each worker said it checked the diff. `intent` found both as well, as in the research.
- Finding 2 (Q2, clean B): both forms raised the two true rows of the research (the docs page shows no one-liner; `install.ps1` maps every non-ARM64 CPU to amd64). The baseline raised three more true rows that `intent` did not: the archive and `checksums.txt` come from separate `latest` URLs and can come from different releases (`install.sh:35-36`); `curl … | sh` can exit 0 when the download fails (`README.md:21`); `POLYBRIEF_VERSION=latest` builds a URL that does not exist in `install.ps1` while `install.sh` treats `latest` as the default. [inference: rows read against the diff, not re-run]
- Finding 3 (Q2, seeded A): the baseline's claude answer added a true `MISSING` row that `intent` did not: the new self-check only covers a blank line before the first setting, so it passes with the over-broad skip (`tests/test_pattern.sh:240-256`). The `intent` judge raised three `CONFLICT` rows for the one defect, restated from three intended items.
- Finding 4 (Q2, clean A): neither form raised a false conflict. `intent` added three benign `MISSING` rows about unchanged behavior; the baseline added none.
- Finding 5 (Q3): the baseline took 41–92 s against 75–97 s for `intent`; input tokens 164k–204k against 107k–270k. The baseline is cheaper on A (one call fewer, no judge over 100k) and dearer on B, where the `intent` describers were small. The baseline gives two independent samples; `intent` gives one judge.
- Finding 6: limits. One run per form; run-to-run variance is not measured (the intent research, Finding 6, saw the judge's lists vary). Two seeded defects, both one-line and visible from the diff alone. Both forms used the same brief wording for the item lists, so the comparison isolates blindness and topology, not prompt quality.

### Variance: runs 2 and 3 of the one-stage form (task 4 of the pattern-candidates plan, removed on 2026-10-22 after it closed)

The built-in one-stage `intent`, binary built from the working tree after the rewrite (future 0.0.4). The same pair, forms and tasks as above. The brief is the kit's new template (`skills/codereview/references/intent.md`), which adds one sentence on the `spec` block. All 8 runs `RESULT complete 2`.

| Form | run | codex conflicts / missing | claude conflicts / missing | wall s | input tokens |
|---|---|---|---|---|---|
| A-seeded | 2 | 1 / 0 | 1 / 1 | 56 | 208,102 |
| A-seeded | 3 | 1 / 0 | 2 / 0 | 58 | 192,100 |
| B-seeded | 2 | 2 / 1 | 1 / 0 | 73 | 137,543 |
| B-seeded | 3 | 2 / 1 | 1 / 0 | 71 | 158,299 |
| A-clean | 2 | 0 / 0 | 0 / 0 | 58 | 221,449 |
| A-clean | 3 | 0 / 0 | 0 / 0 | 61 | 169,727 |
| B-clean | 2 | 4 / 0 | 0 / 0 | 112 | 263,178 |
| B-clean | 3 | 2 / 0 | 0 / 1 | 102 | 173,702 |

- Finding 7: the seeded defect is the first `CONFLICT` row in every answer of runs 2 and 3, 8 of 8. Over three runs that is 12 of 12 answers.
- Finding 8: clean A gave no `CONFLICT` and no `MISSING` in any of the 6 answers of three runs.
- Finding 9: on clean B, two rows recur in every Codex answer of three runs: the docs page shows no one-liner, and every non-ARM64 CPU maps to amd64. Of the extra rows, "separate `latest` URLs" and "`curl | sh` exits 0" came from Codex in runs 1 and 2, not in run 3. "`POLYBRIEF_VERSION=latest` breaks `install.ps1`" came from Claude in run 1 only. Claude found no `CONFLICT` on clean B in runs 2 and 3. In run 3 it raised one `MISSING`: `release-distribution.adr.md` still says "no install scripts". That is the same row as Finding 5 of the intent research. The row is out of date for the current text: `release-distribution.adr.md` already records the reversal of "no install scripts" (Alternative 2, 2026-10-08).
- Finding 10: the decisive rows are stable: the seeded defects, and the absence of conflicts on clean A. The extra true rows on clean B vary from run to run and by worker. Two workers per run cover more of them than one; Codex carried the recurring rows.

## Recommendation

The blind split of `intent`, and with it the `at base` participant, did not add a row over `parallel` with the same row format on these four forms; the baseline found every seeded defect, every true clean-change row, and four more. This is the fourth spike with that result (`ground`, `hypotheses`, `audit`, now `intent`). The value sits in the row format, which is brief text. Keep the name `intent` for the kit contract, but let the built-in become a one-stage form: both workers get the task and the diff, the stage carries `expect` for the rows, and the brief template in the kit carries the row format. `at base` stays in the runtime as a shipped, tested capability with no built-in consumer. Supporting findings: 1, 2, 3, 5.

## Next Action

- Done on 2026-10-22: `patterns/intent.md` is the one-stage form; @README.md, @.archcore/runtime/polybrief-patterns.doc.md, @tests/test_cli.sh and @.archcore/architecture/run-at-base.adr.md (revision) follow.
- Done on 2026-10-22 in ivklgn-kit, uncommitted: the row format is in `skills/codereview/references/intent.md`, and the intent pass spec, scenario and ADR follow.
- Open: one real kit intent pass on polybrief 0.0.4 that ends `RESULT complete 2` and records a yield with two entries. polybrief 0.0.4 and the kit change ship together.
- Done on 2026-10-22: runs 2 and 3 per form, Findings 7–10.
