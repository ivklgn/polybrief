---
title: "Jev as a cheap post-processor of polybrief answers"
status: draft
tags:
  - "codereview"
  - "research"
  - "polybrief"
---

## Idea

Use Jev (TypeSafe, `jev-1.13.0`) for narrow structured decisions over polybrief answers after a run: a separate tool reads the `OUT` directory and asks Jev typed questions — `Choice`, `Score`, `Noul` — about the findings. Jev does not generate text and does not read code on its own (TypeSafe docs, "Jev with coding agents"), so it is never a worker; it only classifies text that code hands it.

Candidate tasks:

| # | Task | Primitive |
|---|---|---|
| 1 | Merge duplicate findings: assign each finding to an existing problem cluster or `none` | `Choice` |
| 2 | Re-grade severity against a rubric with described levels | `Score` |
| 3 | Citation check: code extracts the cited lines, Jev answers whether they support the claim | `Noul` |
| 4 | Yield accounting for `polybrief yield`: map findings to the judge's problem IDs | `Choice` |
| 5 | Pick a pattern or checklists for a brief | `Choice` |

Out of scope: answer format checks (`FINDING`, `NO FINDINGS`) — the `expect` regex already does this in code.

## Value

The measured runs show three costs a cheap classifier could cut (@.archcore/research/polybrief-measured-runs.rnd.md): the judge grouped findings by hand; severity is inflated (codex graded 82% of its findings blocker, the judges 1 of 30 problems); the `refute` stage filtered nothing (58 CONFIRMED of 59 verdicts). Jev costs $0.042 per 1M input tokens with free output (TypeSafe "Models" page); 100 questions of about 3k tokens cost under $0.02 [assumption: estimate from the price list, not measured]. In genui-jev a Choice call took 350–900 ms.

## Possible Implementation

1. Offline experiment first, no change to polybrief: take answers and judge reports from `research/runs-2026-09-29/` in commit `274ed53` (30 kept problems, 36 counted findings, judge severity and kept/dropped per finding).
2. Run tasks 1 or 4 (`Choice` → problem ID), 2 (`Score` vs judge severity) and 3 (`Noul` with cited code vs kept/dropped).
3. Compare with the judges: agreement rate, and whether low confidence marks the wrong answers.
4. Only if agreement is high: a post-processor next to polybrief that reads `OUT` and writes a summary. Embedding a `judge: jev` stage in the runner needs its own decision.

Placement options:

| Option | Trade-off |
|---|---|
| A. Separate post-processor over `OUT` | polybrief unchanged, easy to drop; one more tool |
| B. Stage type in the pattern runner | one command; breaks "no provider" in @AGENTS.md, needs an API key, an ADR and tests |
| C. Caller skill or script (for example `/codereview`) | judging stays with the caller; tied to one caller |

Preferred: A, after the experiment.

## Risks

- [assumption] Accuracy on text about code is unknown: TypeSafe cookbooks cover legal text, catalogues and moderation, not code review.
- Jev reads literally and is weaker on indirection; two findings about one problem in different words are indirection (TypeSafe "Jev 1.13 jaggedness").
- `Score` sees the finding text, not the code: it grades wording, not real risk.
- The filter gain of task 3 is small: the judges dropped only 6 of 36 findings.
- In genui-jev, Jev and rules both scored 9/9 on the A/B/C selection fixture; no quality advantage of Jev was found there.
- Jev needs an API key and sends findings and code excerpts to another vendor; polybrief runs on subscriptions with no keys, and the secret-name filter covers only the diff.
- English is Jev's primary language; Russian briefs and answers may score lower.
- The context limit is 64k tokens per request and 32k for state plus the longest question; a whole run does not fit in one call.