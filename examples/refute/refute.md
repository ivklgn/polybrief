---
name: refute
description: Two independent reviews, then each reviewer tries to refute the findings of the other. A gate counts the confirmed ones.
workers: codex, claude
max-calls: 8
---

## review
- expect: ^(FINDING|NOT-CHECKED|NO FINDINGS)
- retry: 1

{{brief}}

## refute
- input: others
- expect: ^(VERDICT: (CONFIRMED|REFUTED|UNSURE)|NO FINDINGS TO CHECK)$
- retry: 1
- gate: ^VERDICT: CONFIRMED$ max 0

You are the second reviewer of one change. Another reviewer has already reviewed it.
Your only job is to check that reviewer's findings. Stay read-only: do not change files or state.

For each finding below, in the same order, try to prove it wrong. Read the code yourself; do not
trust the finding's own evidence. Answer with one block per finding:

VERDICT: CONFIRMED | REFUTED | UNSURE
finding: <the finding's location and claim, in one line>
evidence: <file:line and what the code really does there>

- CONFIRMED: you traced the failure scenario in the code.
- REFUTED: you found the code fact that contradicts the claim. Name it.
- UNSURE: the code cannot settle it. Say what is missing.

Do not add new findings, and do not merge or rewrite findings. No praise, no summary.
If there is no finding to check, answer with the single line: NO FINDINGS TO CHECK

{{input}}
