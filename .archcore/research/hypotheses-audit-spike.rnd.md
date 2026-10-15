---
title: "Hypotheses and audit spikes: role and lens split against parallel"
status: rejected
tags:
  - "polybrief"
  - "research"
  - "source:measurement"
---

## Goal

Decide whether the `hypotheses` and `audit` patterns of @.archcore/ideas/research-patterns.idea.md are worth building in, after @.archcore/research/ground-pattern-spike.rnd.md did not keep `ground`. Date: 2026-10-15.

## Questions

1. Does `hypotheses` (one hypothesis per worker, then a `swap` check) give correct verdicts in both vendor orders?
2. Does `parallel`, with both hypotheses and the same output format in the brief, give the same verdicts?
3. Does `audit` (codex lens `evidence`, claude lens `coverage`) find true problems in real `/research` briefs, or only agree?
4. Does `audit` find true problems that `parallel` with the same row format misses, and the reverse?
5. What do both patterns cost against `parallel`?

## Approach

- polybrief 0.0.2 (installed). Workers: codex `gpt-6-sol` and Claude Code on their defaults. One run per form. All 13 runs `RESULT complete`, every call `ok`.
- `hypotheses`, three cases. Each base tree is `git archive` of the buggy state, made a one-commit repository so the fix is not visible:

| Case | Base | Symptom | True | False |
|---|---|---|---|---|
| A | `130423a` (fixed by `1c044aa`) | blank line after `## answer` makes `plan` show both header workers | H2: settings reader stops at the blank line | H1: a bare `run: codex` is not parsed |
| B | ivklgn-kit `591e1b6^` | after a force-push, a clean review worktree reports `kept-ahead` | H1: `ensure_worktree` moves only on ancestry | H2: the branch is not fetched again |
| C | `5c2c5d9` with the seeded empty-checksum test of the intent research | install continues without a checksum line | H2: the test accepts an empty `want` | H1: `fail` inside `main` does not stop the script |

- Vendor orders: one pattern file with `codex as h1, claude as h2`, a second with the roles swapped. The `swap` stage repeats the same `run: <worker> as h1/h2` lines, because `input: others` matches participants by name (`runner.go`, `input` selection). A `swap` stage without its own `run` lines would hand each worker both earlier answers. The `parallel` baseline gives both hypotheses to both workers and asks for both verdicts.
- `audit` uses the two finished `/research` briefs that exist: "участник `at base`" (session of 2026-10-15) and the brief that proposed this spike. The tree is `b3cfc5d` plus the untracked documents both briefs cite, in their state at brief time, with ivklgn-kit as a context directory (`-o context_dirs=`). The `parallel` baseline asks both workers for the same `HOLDS` / `FAILS` / `MISSING` rows.
- Materials are in the temporary session scratchpad and are not kept.

## Findings

### Hypotheses

| Case | Form | Verdicts | Wall s | Input tokens |
|---|---|---|---|---|
| A | codex h1 / claude h2 | correct, swap confirms | 92 | 314,784 |
| A | claude h1 / codex h2 | correct, swap confirms | 73 | 274,245 |
| A | parallel | both workers correct | 52 | 213,295 |
| B | codex h1 / claude h2 | correct, swap confirms | 70 | 182,528 |
| B | claude h1 / codex h2 | correct, swap confirms | 85 | 264,434 |
| B | parallel | both workers correct | 43 | 157,911 |
| C | codex h1 / claude h2 | correct, swap confirms | 82 | 203,328 |
| C | claude h1 / codex h2 | correct, swap confirms | 93 | 190,442 |
| C | parallel | both workers correct | 48 | 117,567 |

- Finding 1 (Q1, Q2): all 6 `hypotheses` runs and all 3 `parallel` runs (6 answers) supported the true hypothesis and refuted the false one. The vendor order changed nothing.
- Finding 2: the `swap` stage confirmed the other worker's evidence and corrected two overstatements, both in case B. One was "no test exercises a re-run": `test_resolve_target.sh` covers a re-run after a normal push. The other was a claimed conflict with the resolve-target spec. Neither changed a verdict.
- Finding 3 (Q5): `hypotheses` cost 70–93 s and 182k–315k input tokens. `parallel` cost 43–52 s and 118k–213k. That is about 1.7× the time and 1.2–1.7× the tokens.
- Finding 4: limit of the test. In each case the false hypothesis can be refuted by reading the code (for example, the fetch in `resolve_target.sh` and `exit 1` in `fail`). Cases where the code alone cannot decide are not tested. The cases mix one real bug here, one real bug in ivklgn-kit and one seeded defect. The idea asked for three real fixes from this repository.

### Audit

| Brief | Form | holds | fails | missing | Wall s | Input tokens |
|---|---|---|---|---|---|---|
| at base | audit | 6 | 3 | 11 | 158 | 1,060,255 |
| at base | parallel codex / claude | 8 / 14 | 3 / 5 | 4 / 6 | 123 | 835,897 |
| this spike's brief | audit | 7 | 2 | 11 | 180 | 641,745 |
| this spike's brief | parallel codex / claude | 3 / 13 | 1 / 8 | 4 / 4 | 136 | 782,306 |

- Finding 5 (Q3): `audit` did not rubber-stamp. Both briefs had real errors, and both forms found them. Rows checked against the code and documents:
  - `run-at-base.proposal.md` (since replaced by @.archcore/architecture/run-at-base.adr.md and removed), sample pattern: the `compare` stage sets `input: all` but has no `{{input}}`, so the judge gets no answers. The built-in `patterns/intent.md` has it. The runner inserts answers only through the placeholder (`runner.go`, `render`). Found only by `audit` (evidence lens).
  - "Kit accepted the contract, so build now": only the kit integration spec is accepted. `intent-pass-separate-run.adr.md` is `draft`, and the pass is opt-in. Found by both forms.
  - "Always ends `pattern not available`": only when the request carries `intent`. Found by both forms.
  - The kit ADR names a third way out: a pattern on stdin or inline. Found by both forms.
  - A snapshot under `OUT` sits next to `change.json` and other answers, so isolation would leak. Found by both forms.
  - "`intent` establishes a need for `-m`" is not shown: the kit contract and the experiment use `-c`. Found by both forms. The later challenge of the `intent` fork reached the same result.
  - The idea says "Each worker gets **one** hypothesis", which the second brief left out. Found by both forms.
  - The second brief audits itself (circular case). Found by both forms.
  - The `stale` check compares a fingerprint of the context, not only the directory (`runner.go`, `contextMoved`). Found only by `parallel` (codex).
- Finding 6 (Q4): each form had one or two true rows the other missed (Finding 5). The `parallel` claude answer on the second brief had at least four false `FAILS` rows. Line numbers were checked on the wrong commit; it said `38776e4` "is not a fix", although it is both a fix commit and the base of change B; it said the seeded case cannot be reproduced. The tree setup caused these, and the `audit` evidence lens had one row of the same kind. [inference: not every row of the 4 runs was verified]
- Finding 7 (Q5): `audit` cost 158–180 s and 0.64M–1.06M input tokens, against `parallel` at 123–136 s and 0.78M–0.84M. The cost is about the same.

### Across the three spikes

- Finding 8: in all three spikes, `ground`, `hypotheses` and `audit`, a `parallel` run whose brief carries the same row format found the same decisive rows. The role or lens split did not add a class of results. This matches the measured review runs, where lenses added nothing over an independent sample (@.archcore/research/polybrief-measured-runs.rnd.md, Finding 4).

## Recommendation

Stop. Do not build `ground`, `hypotheses` or `audit` into polybrief, and do not add the material channel (`-m`, `given`) for them. The value is in the row formats (`ALREADY`/`GAP`/`CONFLICT`/`BREAKS`/`UNCLEAR`, `VERDICT`/`EVIDENCE`/`DISCRIMINATOR`, `HOLDS`/`FAILS`/`MISSING`). They need no runtime change: the kit's `/research deep` already runs `parallel` with its own brief template. Supporting findings: 1, 3, 5, 6, 8. One case for revisiting `hypotheses`: problems where code reading alone cannot decide (Finding 4).

## Next Action

- `/archcore:document`:
  - mark @.archcore/ideas/research-patterns.idea.md as rejected by this result.
- ivklgn-kit (not this repository): add the row formats to `skills/research/references/deep.md` as brief variants for a task, a problem and a brief check.
- `at base` and the built-in `intent` are already drafted in the working tree (@.archcore/architecture/run-at-base.adr.md, uncommitted on 2026-10-15). They take the base tree outside `OUT` (`TMPDIR/polybrief-base.*`), and `patterns/intent.md` carries `{{input}}`. A real `intent` run on that change (codex `gpt-6-sol` and claude `opus` at medium, 3 calls, 136 s, 404k input tokens) completed and removed the base tree. Its judge raised one true `CONFLICT`: a `die` inside `execute` (for example, launcher exit 2) skips the removal. The kit ADR is still `draft`.
