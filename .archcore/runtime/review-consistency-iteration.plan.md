---
title: "Swarm review iteration: consistency, data minimization, and quality"
status: accepted
tags:
  - "codereview"
  - "polybrief"
---

## Goal

Make review runs reproducible at the supplied-input level, fail visibly on preparation and artifact errors, reduce automatic data sent to workers, and measure review quality before changing pattern defaults. The caller retains evidence verification and the final decision.

## Clarifications

- The user selected all three workstreams: input consistency and launch errors; data boundary; review-quality measurement.
- The user selected data minimization with explicit limits, without an OS-level file-read isolation guarantee.
- The user authorized available local review cases and at most 20 live model calls. The existing c1/c2 issue labels are prior expert judgments, not human labels.
- [assumption] Persistent working-tree drift invalidates a run result; a file changed and fully restored during a worker call cannot be detected by an end-of-run check.

## Current-State Verdicts

- `code-wrong`: @launch.go invokes Git before rejecting `TMPDIR` inside `DIR`. The launcher contract requires refusal before a write; @tests/test_review.sh exposed macOS Git creating `xcrun_db` in the target.
- `code-wrong`: @launch.go ignores `change.diff` and `prompt.md` write failures and brief/checklist read failures. @runner.go ignores prompt, answer, and status I/O failures. The launcher contract requires exit 2 when the diff cannot be made.
- `ok`: @runner.go passes `--base` to each launcher, as the current runner contract requires. That contract has no captured-input guarantee across stages; each launcher currently rebuilds its own change context.
- `ok`: @runner.go accepts a stage with at least one `ok` answer, as specified. A new aggregate line can expose partial success while preserving individual statuses.
- `ok`: @launch.go omits secret-like files from the generated diff, as specified. It still sends skipped path names and caller-supplied text; workers can read files allowed by their OS account. @README.md already states the filesystem limit.

## Tasks

### Phase 1 — Contracts and measurement baseline

1. Define prepared-input, drift, aggregate-result, and error semantics — @.archcore/runtime/polybrief-review.spec.md, @.archcore/runtime/polybrief-pattern-runner.spec.md, @.archcore/runtime/polybrief-cli.spec.md.
2. Specify automatic prompt sources and disclosure limits; keep caller-supplied briefs explicit — @.archcore/runtime/polybrief-review.spec.md, `docs/code-review.md` (removed 2026-10-04).
3. Freeze case snapshots, review briefs, issue labels, CLI versions, settings, and call budget — @tests/, @.archcore/research/.
4. Measure old/new `parallel` and new `twice`/`panel` on c1/c2 within 20 model calls.

### Phase 2 — Preparation and errors

5. Validate target, configuration, and temp paths before Git or worker startup — @launch.go, @runner.go.
6. Propagate brief, checklist, diff, prompt, answer, and status I/O errors — @launch.go, @runner.go, @main.go.
7. Add fake-worker fixtures for unreadable inputs, failed writes, and `TMPDIR` inside target — @tests/test_review.sh, @tests/test_pattern.sh.

### Phase 3 — Consistent supplied input

8. Capture base SHA, diff, history, brief, and checklists once per review run — @launch.go, @runner.go.
9. Reuse prepared input across participants and stages through the launcher — @launch.go, @runner.go.
10. Fingerprint selected inputs before and after preparation and execution; reject persistent drift — @launch.go, @runner.go, @tests/test_pattern.sh.
11. Cover staged, unstaged, untracked, binary, secret-name, and concurrent-edit cases — @tests/test_review.sh, @tests/test_pattern.sh.

### Phase 4 — Data minimization and comparison

12. Replace skipped path names in worker prompts with counts; retain local operator diagnostics — @launch.go, @tests/test_review.sh.
13. Audit generated prompts by diff, history, path, brief, and checklist bytes — @launch.go, @tests/test_review.sh.
14. Bound automatically added history and path lists; report omitted counts — @launch.go, @tests/test_review.sh.
15. Normalize findings against reference labels; inspect disputes and disclose non-blind review — @.archcore/research/.
16. Compare confirmed findings, false positives, elapsed time, tokens, and prompt bytes — @.archcore/research/, `docs/code-review.md` (removed 2026-10-04).
17. Document trade-offs and keep pattern defaults until labeled results support a change — @README.md, `docs/code-review.md` (removed 2026-10-04).
18. Run Go and shell checks; inspect public status and output compatibility — @tests/test_cli.sh, @tests/test_review.sh, @tests/test_pattern.sh.

## Acceptance Criteria

- Fake-worker evidence shows identical prepared Git context and caller inputs across participants and stages.
- Drift and I/O failure fixtures exercise the recorded exit/status contract, including retained partial answers.
- Prompt fixtures show that the generated diff excludes secret-like file content and the omission notice gives only a count. History subjects and caller-supplied text may still contain names. Tests exercise bounds on automatically added history and paths.
- Documentation says which data Swarm sends and that workers may read files visible to the OS account.
- A versioned exploratory comparison reports matches to the prior expert labels, disputed claims, elapsed time, reported tokens, and prompt bytes per condition. Record non-blind review and missing data; avoid a general quality claim from two cases.
- Historical imported runs remain labeled as ivklgn-kit evidence; no current-quality claim uses them as a Go-runtime validation.
- `go test ./...`, `bash tests/test_review.sh`, `bash tests/test_pattern.sh`, and `bash tests/test_cli.sh` pass.
- `go.mod` retains standard-library-only dependencies.

## Dependencies

- Keep worker startup and isolation flags in @launch.go and configuration parsing in @config.go; @runner.go starts workers only through the launcher.
- Preserve caller ownership of briefs, checklists, evidence verification, and final decisions.
- The stored diff does not freeze files workers read from `DIR`; fingerprints cover selected change inputs, not every readable file.
- The two available local cases have reconstructable code and prior expert labels, but no independent human issue labels. This limits conclusions about quality; any broader claim needs a human-adjudicated corpus.
- [assumption] Compare only configurations with identical model versions, effort, case snapshots, and briefs; record missing usage data instead of treating it as zero.

## Outcome of this implementation

- Preparation, context reuse, drift detection, aggregate results, disclosure bounds, and required I/O error handling are implemented in @launch.go, @runner.go, and @main.go.
- Fake-worker checks and the Go unit test pass; the four required project checks and `git diff --check` pass.
- The 20-call comparison is recorded in @.archcore/research/polybrief-go-review-comparison.rnd.md. Old/new `parallel` prompts matched after tag normalization on both cases. The sample does not justify changing the default pattern.
- The benchmark binary predates final corrections for invalid `TMPDIR` and binary-file drift; the final source and fake-worker checks include both.
- The prior issue labels are expert-agent judgments, not human labels. This limits quality conclusions and replaces the initial assumption of a human-adjudicated corpus.

## Declared Delta

- Route: amendment (size M).
- Creates: none; the measurement protocol is project evidence, not a new runtime capability.
- Modifies: launcher preparation and disclosure behavior; runner input reuse and aggregate status; public CLI result contract.
- Retires: none.
- Decision: none settled on pattern defaults; the measurement determines whether a later decision is warranted.
- Intent gap: no; accepted runtime decisions already frame local read-only execution and caller judgment.
- Gap profile: machine evidence from @launch.go, @runner.go, current specs, and fake-worker tests; user choices fix scope and disclosure boundary; empirical quality evidence remains an implementation task.
- Maturity: stone; accepted runtime and pattern-runner decisions cover the touched zone.
- Risk: external-contract for status and exit semantics. No new filesystem access-control or compliance claim is proposed.
- Rationale: prepare and validate inputs before drawing quality conclusions; compare the cost and findings of any data reduction against a fixed baseline.
