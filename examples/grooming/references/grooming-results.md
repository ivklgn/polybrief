# Grooming reference

## What runs

`grooming.md` is a pattern file in this folder, passed with `-p FILE` from a
copy outside the repository, because Polybrief refuses a pattern file inside
the tree it looks at. It has
one stage, `refine`, with Codex and Claude. Both get the brief, with the item
inside it, and the tree; neither sees the other's answer. The stage sets
`expect` for the row words and `retry: 1`. Without them a run with no Git base
accepts any text as an answer; with them a prose answer is `malformed` and the
worker is called once more. That is why the skill uses a pattern file instead
of the built-in `parallel`.

Run `polybrief plan -p ./grooming.md` to inspect the calls without a model.

## Rows

| Row | Meaning |
| --- | --- |
| `ALREADY \| asked [explicit\|inferred] \| exists \| file:line` | the system already does it |
| `GAP \| asked [explicit\|inferred] \| missing \| file or package` | real work |
| `CONFLICT \| asked \| contradicts \| file:line or document` | the item goes against a contract, default or recorded decision |
| `BREAKS \| existing \| asked point \| file:line` | the item changes existing behavior without saying so |
| `UNCLEAR \| asked \| readings` | the item has two readings in this system |
| `SUMMARY already=N gap=N conflict=N breaks=N unclear=N` | counts |

What to do with each row is in `SKILL.md`.

## What the measurements say

The repository measured this row format on four seeded items against its own
code: one asking for things that already exist, one contradicting an accepted
decision record, one silently changing a naming contract, and one clean. Two
forms ran: a three-call form where one worker saw the item without the code's
current behavior, another described the behavior without seeing the item, and
a judge matched the lists; and `parallel` with the item and the rows in one
brief. Both forms raised every seeded row on every item: the `ALREADY` rows
for the existing commands, the `CONFLICT` with the decision record, the
`BREAKS` at the naming check. The split added no row and cost about 1.7 times
the wall time (`.archcore/research/ground-pattern-spike.rnd.md`, Findings 1 and
2). So this skill gives both workers the same brief in one stage.

Two limits from those runs: one run per item, so the spread between runs is
not measured; and an item written with an error produces a false `CONFLICT`,
so read the item as critically as the code.

The sample brief in this folder is the second seeded item in a product voice.
Expect a `CONFLICT` with the decision record that removed the settings file
(`.archcore/architecture/arguments-only-runtime.adr.md`) and `ALREADY` rows for
`polybrief plan` and `polybrief patterns`.

## Adapting it

- The `## Scope` section of the brief sets where the workers look. Name the
  packages and the decision records; a whole repository makes the rows vague.
- Add a row kind, for example `RISK`, by adding its word to `expect` in
  `grooming.md` and describing it in the prompt. A row word missing from
  `expect` does not make an answer `ok`.
- To use OpenCode, pass `-w codex,opencode -o opencode.model=provider/model`.
