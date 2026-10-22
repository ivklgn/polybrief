# Done check reference

## What runs

The skill uses the embedded `intent` pattern: one stage, `compare`, with Codex
and Claude. Each worker gets the brief, the `task` checklist block, the diff
from `-b`, and the tree after the change. Neither sees the other's answer. The
stage has `expect: ^(CONFLICT|MISSING|EXTRA|UNCLEAR|MATCH|SUMMARY)`, so a row
answer is `ok` and an answer without a row is `malformed`. `-w` replaces the
workers; OpenCode needs `-o opencode.model=provider/model`.

The pattern does not refuse a run without `-b`: the workers then see no change
and every intended item becomes `MISSING`. Always pass the base.

Run `polybrief plan -p intent -w codex,claude` to inspect the two calls.

## Rows

| Row | Meaning |
| --- | --- |
| `CONFLICT \| intended [explicit\|inferred] \| built \| why \| file:line` | the task and the change disagree |
| `MISSING \| intended [explicit\|inferred] \| not described by built \| what the diff shows` | the task asks for it, the worker did not find it |
| `EXTRA \| built \| not asked by the task \| file:line` | the change does something the task did not ask |
| `UNCLEAR \| item \| what is unknown` | the task has two readings, or the diff does not settle it |
| `MATCH \| intended \| built` | the descriptions agree |
| `SUMMARY conflicts=N missing=N extra=N unclear=N matches=N` | counts |

What to do with each row is in `SKILL.md`.

## What the measurements say

The one-stage form was compared with an earlier three-call form, where one
worker saw the task without the diff, one saw the diff without the task, and a
judge matched the two lists. On four changes, two clean and two with seeded
defects, the one-stage form found every seeded defect and more true rows at a
lower cost; the blind split added no row. The value sits in the row format of
the brief, not in the stage structure. The runs are recorded in the repository
under `.archcore/research/intent-baseline-spike.rnd.md` and
`.archcore/research/intent-pattern-experiment.research.md`.

Two limits from those runs: the rows vary between runs on the same change, so
a second run can raise a row the first did not; and a task text written with
an error produces a false `CONFLICT`, so check the task as well as the code.

Cost on the measured changes of 92 and 191 diff lines: 2 calls, 41–92 seconds,
164k–204k input tokens. Larger changes cost more.

## Adapting it

- This brief is the measured one with one addition: the `[explicit|inferred]`
  mark in `CONFLICT` and `MISSING` rows, so the caller can weigh a row. The
  mark was not part of the measured runs.

- Edit `references/brief.md` to add rows or change the two steps. Keep the
  first word of each row in the pattern's `expect`, or the answer is `malformed`.
- A specification changed by the same change goes in as `-c spec.md`. The brief
  tells the workers to read it as the author's statement, not as the task.
- To change the row words, copy `patterns/intent.md` from the repository, edit
  its `expect`, and pass the file with `-p`.
