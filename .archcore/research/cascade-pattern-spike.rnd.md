---
title: "Cascade pattern spike: second worker on a condition, derived from the measured runs"
status: rejected
tags:
  - "polybrief"
  - "research"
  - "source:measurement"
---

## Goal

Tasks 2 and 3 of the pattern-candidates plan (removed on 2026-10-22 after it closed): do the two cascade variants spend fewer calls than `parallel` without losing a known problem? `cascade`: Claude reviews, Codex reviews only `when: first has ^FINDING`. `cascade-clean`: Codex reviews only `when: first lacks ^FINDING`. Claude goes first because one Claude answer found more problems (25 of 30 against 15, @.archcore/research/polybrief-measured-runs.rnd.md, Finding 6). Date: 2026-10-22.

## Questions

1. How many calls does each variant spend on the five changes c1–c5?
2. Which known problems does each variant lose against the `parallel` run on the same answers?

## Approach

No new model runs. A cascade's first stage is the Claude answer of a `parallel` run and its second stage is the Codex answer of that run, so the problem table of the measured runs (columns `p1` and `p2`, 10 runs, 30 kept problems) gives the outcome of both variants. The plan asked for two new runs per form. They were not made because the table decides the outcome, as shown below. The re-run would also be weaker than the recorded runs: the c5 defect key (`research/runs-2026-09-29/c5-seeded.md`) is not kept.

Assumption: a cascade answer equals the `parallel` answer of the same worker on the same change. The prompts are the same. Only the time of the call differs. [assumption]

## Findings

- Finding 1 (Q1): every Claude answer of the 10 `parallel` runs has at least one kept finding (table rows `p1 cl`, `p2 cl`). So `when: first has ^FINDING` holds in every run. `cascade` spends 2 calls in 10 of 10 runs, the same as `parallel`. The calls run one after another, so the wall time is the sum of the two calls instead of the slower one.
- Finding 2 (Q1): for the same reason `cascade-clean` never runs Codex. It spends 1 call in 10 of 10 runs.
- Finding 3 (Q2): `cascade` loses nothing. It is `parallel` with a longer wall time.
- Finding 4 (Q2): `cascade-clean` loses problems in 4 of 10 runs, the Codex-only rows of the table:

| Run | Lost (found only by Codex in that run) |
|---|---|
| c2 p2 | P4 pending view dropped by arrival order |
| c4 p2 | P3 install marker for 24 h; P11 quoted text against `short()` |
| c5 p1 | S3 CSI final byte not consumed (blocker) |
| c5 p2 | S3 (blocker); S2 Ctrl bit tested as Alt bit (major) |

- Finding 5: limit. All five changes have problems. A cascade saves calls only on changes where the first answer is `NO FINDINGS`, and the corpus has none. The one-stage `intent` clean forms use another row format and do not apply.

## Recommendation

Drop both variants. Neither meets the keep rule of the plan: `cascade` spends no fewer calls, and `cascade-clean` loses the only blocker of the corpus in both runs. The example files written for task 1 are removed. `when` stays specified in @.archcore/runtime/polybrief-pattern-file.spec.md, and `tests/test_pattern.sh` checks each of its forms. Revisit only with a corpus that holds clean changes and a first worker whose `NO FINDINGS` has been checked. Supporting findings: 1, 2, 4.

## Next Action

- None in polybrief. The plan's task 3 is closed by this result. The plan was removed on 2026-10-22 after all its tasks closed.

Candidates the plan did not take up, with the reason (moved here from the removed plan):

- `ground`, `hypotheses`, `audit` and the material channel `-m`: rejected by @.archcore/research/ground-pattern-spike.rnd.md and @.archcore/research/hypotheses-audit-spike.rnd.md.
- Debate with a consensus protocol over `crosscheck`: the refute stages confirmed 58 of 59 verdicts (@.archcore/research/polybrief-measured-runs.rnd.md, Finding 5). No new measurement until a protocol other than "exchange and confirm" is written, for example cross-inhibition: a participant that sees a conflict answers UNDECIDED and names the discriminating evidence.
- Dynamic orchestrator-workers, supervisor trees, self-organizing swarms: outside the declared-pattern runtime by @.archcore/architecture/general-purpose-pattern-runtime.adr.md.
- Learning edge (kept findings become constraints of the next brief): an ivklgn-kit idea, `.archcore/codereview/ideas/learning-edge-from-kept-findings.idea.md` there; polybrief owns no part of it.
