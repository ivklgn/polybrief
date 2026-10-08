---
name: twice
description: Two independent answers from each worker to the same brief. Your agent judges.
workers: codex, claude
max-calls: 4
---

## review

- run: codex as codex-1
- run: codex as codex-2
- run: claude as claude-1
- run: claude as claude-2

{{brief}}
