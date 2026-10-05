---
title: "Go Swarm review comparison on two local cases"
status: draft
tags:
  - "codereview"
  - "source:measurement"
  - "polybrief"
---

## Goal

Assess whether the Go Swarm review iteration changes finding quality or cost, and whether a pattern default should change. The launcher and runner changes are specified in @.archcore/runtime/polybrief-review.spec.md and @.archcore/runtime/polybrief-pattern-runner.spec.md.

## Questions

- Do the new launcher and runner lose reference findings on the same local cases?
- What extra reference findings do `twice` and `panel` return for their call cost?
- Does the data-minimization change alter worker prompts in these cases?

## Approach

- Cases: reslop c1 at `5b6d983266ae72949f57ea476dd9b55a430b67d2` (base `2461dd655c203f0a65c14dc246b5baa7bec70cab`) and visualizer c2 at `91b2c3a4070ff366113f31520ba07783d30ba516` (base `e785950eab35fa8b812fab9ae86e016348f651d9`). Reference issue labels come from @research/runs-2026-09-29/c1-judge.md and @research/runs-2026-09-29/c2-judge.md. Those judgments were made by a Claude subagent, not an independent human.
- Old binary: repository `HEAD` `c87789e1545d6fb098c44f984ac40a516f601804`, SHA-256 `a1d60be55c4aeb86d2254c1b930a2d020442f0eb88d971d31ebac47fb11b20a1`. New benchmark binary: local implementation, SHA-256 `506ef3fa271882d5910ff0b91c2595ffbd800783dd671436c2c33946f4418e20`. Later preflight and exact file-fingerprint fixes are in the final source but not that benchmark binary; the final source builds to SHA-256 `46d6a23be3890ba163fdebab5457a0935852e8275313c6773eae0bdfac712001`. These fixes do not change generated worker prompts for the two static cases.
- CLIs: Codex 0.159.0 with `gpt-6-sol`, medium effort; Claude Code 2.1.286 with `opus`, high effort. Provider aliases do not pin dated model builds. Timeout was 900 seconds; history and tool logging were on. Brief/config checksums and full command matrix are in the local protocol at `/Users/ivklgn/.local/state/swarm/bench-2026-10-01/protocol.md`.
- Twenty live calls: old/new `parallel` for each case (8), new `twice` for each (8), new `panel` for each (4). The `panel` call limit was set to two, so a malformed answer would not retry. Caller-supplied panel checklists came from ivklgn-kit plugin 0.6.0; this creates no runtime dependency.
- `Wall` is the elapsed time from run-output file creation to its final write, rounded to seconds. Tokens are summed counters reported by the CLIs, including cache traffic; they are not a bill estimate. Prompt bytes sum all launcher prompts in the condition. Raw outputs and snapshots are in `/Users/ivklgn/.local/state/swarm/bench-2026-10-01/`, outside the repository.

## Findings

| Case | Condition | Calls | Matched reference IDs | Wall s | Input tokens | Output tokens | Prompt bytes |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: |
| c1 | old parallel | 2 | P1 P2 P3 P4 | 303 | 1,006,046 | 12,117 | 39,664 |
| c1 | new parallel | 2 | P1 P2 P3 P4 | 115 | 650,217 | 11,272 | 39,664 |
| c1 | new panel | 2 | P1 P2 P3 | 104 | 607,061 | 9,688 | 46,715 |
| c1 | new twice | 4 | P1 P2 P3 P4 P5 | 344 | 1,556,352 | 23,421 | 79,328 |
| c2 | old parallel | 2 | P1 P2 | 129 | 1,198,584 | 12,476 | 150,682 |
| c2 | new parallel | 2 | P1 | 345 | 1,473,369 | 20,349 | 150,682 |
| c2 | new panel | 2 | P1 P2 | 132 | 1,015,893 | 12,587 | 157,733 |
| c2 | new twice | 4 | P1 P2 P8 | 169 | 2,710,913 | 35,630 | 301,364 |

| Case | Condition | Additional claim outside old labels | Confirmed false issue-level claims |
| --- | --- | --- | ---: |
| c1 | all four | none | 0 |
| c2 | old parallel | outdated conformance example: confirmed | 0 |
| c2 | new parallel | conflict-spec mismatch: confirmed; pending-decode mode request: provisional | 0 |
| c2 | new panel | conflict-spec mismatch: confirmed | 0 |
| c2 | new twice | conflict-spec mismatch: confirmed | 0 |

- All 20 calls returned `ok`. All new runs returned `RESULT complete`. In c1, `twice` added only P5, a cosmetic coloring issue found by one Claude answer. In c2, `twice` added P8 to the two common reference findings; none of these patterns found P4 or P9.
- After replacing only the random change tag, the old/new `parallel` launcher prompts were byte-identical within each case. Per current parallel worker, c1 had 2,490 stage-brief bytes + 1,012 history + 16,052 diff + 278 wrapper = 19,832; c2 had 2,508 + 3,158 + 69,397 + 278 = 75,341. The panel risk prompt added 6,251 checklist bytes. Both cases had zero skipped secret-like paths and no path/history truncation. Thus the c2 finding difference does not show a prompt-regression caused by the iteration; model execution and timing remain variable.
- The earlier reference labels are incomplete. Static inspection confirmed three additional c2 candidates: an outdated 20,000-character conformance example in `mcp-tools.spec.md` (old parallel), conflict rules that still demand only `_meta.view` although large responses use `viewCompressed` (new parallel/panel/twice), and a mode-change path that requests `workspace_state` while decoding can still be pending (new parallel). The last candidate has no host reproduction; its severity remains open. These candidates are not counted as false positives merely because the old label set lacks them.
- Several answers overstated severity: c1's width bug was called major/blocker despite being display-only; some said the row wraps and shifts the footer, while autowrap is off. c2's test-title convention was repeatedly called blocker despite having no runtime effect. One c2 panel answer also treats a telemetry clause as exclusive when it is not. These are false explanatory subclaims, even where the issue-level finding is real.
- Finding review was not fully blind: the reviewer saw one answer with its model name before scoring. The sample has two cases, model aliases may change, and old `twice`/`panel` were not rerun. Elapsed time and token differences do not establish a causal performance effect.

## Recommendation

Keep `parallel` as the default. The implementation now freezes supplied Git context, brief and checklists across stages and exposes stale/partial outcomes, while the two-case live sample gives no defensible reason to change pattern defaults. Use `twice` when the caller values additional low-frequency findings enough for twice the calls; treat `panel` as a lens choice, not a proven quality improvement.

## Next Action

Build a larger, independently adjudicated corpus with more than two changes, including secret-name omissions and truncated diffs. Pin model build IDs where possible, repeat each condition, and compare issue quality and severity calibration before changing defaults.