---
name: intent
description: Does the change do what the task asks? Each worker compares the task with the diff and reports one row per item. Pass -b and the task as -c task.md; without -b the workers see no change.
workers: codex, claude
max-calls: 3
---

## compare

- expect: ^(CONFLICT|MISSING|EXTRA|UNCLEAR|MATCH|SUMMARY)

{{brief}}
