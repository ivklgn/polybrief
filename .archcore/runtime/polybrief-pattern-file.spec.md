---
title: "Polybrief pattern file format"
status: draft
tags:
  - "polybrief"
  - "spec"
---

## Purpose & Scope

Normative for polybrief pattern files: what a file holds and how each part is read. Dependents: the runner (@.archcore/runtime/polybrief-pattern-runner.spec.md), pattern authors, and consumers such as `/codereview`. Out of scope: how workers are started, the content of the brief, and the caller's evaluation of results. The decision is in @.archcore/architecture/polybrief-pattern-runner.adr.md. Built-in patterns are in @patterns/; @docs/code-review.md shows one use case, and the polybrief reference doc contains complete pattern examples.

## Surface

- Location: the user's `patterns_dir` (default `~/.config/polybrief/patterns/<name>.md`), then the built-in `patterns/<name>.md` (embedded in the Go binary), or a file path: a value that contains `/` or ends in `.md`. A user file replaces a built-in pattern of the same name.
- Header: the block between the first two `---` lines, one `key: value` per line.

| Header key | Meaning | Default |
|---|---|---|
| `name` | name of the pattern | required |
| `description` | one line for people | required |
| `workers` | participants of a stage that has no `run`, comma-separated | required |
| `max-calls` | highest number of launcher calls in one run | the setting `max_calls`, 12 |

- Stage: one `## <id>` section. Its settings are the `- key: value` lines right under the heading; blank lines between the heading and the first setting are skipped, as Markdown formatters add one. After the first setting, the first other line starts the stage prompt; leading blank lines of the prompt are dropped. A `## ` line always starts a new stage, so a prompt uses `###` for its own headings.

| Stage setting | Value | Default |
|---|---|---|
| `run` | `<worker> [as <role>] [with <lane>+<lane> \| run \| none]`; the line may repeat | every header worker, with the lanes of the run |
| `input` | `none`, `own`, `others` or `all` | `none` |
| `from` | id of an earlier stage | the stage before |
| `rounds` | 1 to 5 | 1 |
| `until` | expression; the rounds end when every answer matches | none |
| `when` | `<stage> has <expr>`, `<stage> lacks <expr>`, `<stage> passed` or `<stage> blocked` | always |
| `expect` | expression that an answer has to match | none |
| `retry` | 0 to 2 further calls after a `malformed` answer | 0 |
| `gate` | `<expr> max <N>`: the stage passes when at most N lines match | none |

- Placeholders in a stage prompt: `{{brief}}` the brief of the run; `{{input}}` the answers chosen by `input`; `{{name}}` the participant name (the role, else the worker); `{{role}}` the role, empty without one; `{{round}}` and `{{rounds}}`.
- Lanes in `with`: a lane is a checklist the caller supplies (`-c FILE` on the command line, `--agents-dir` with `--lanes` for the internal launcher), named by its file name without `.md`. `run` means every checklist of the run, `none` means no checklists.
- Names: a pattern name, a stage id and a role hold `a-z`, `0-9` and `-`.
- Expressions: POSIX extended regular expressions, matched against one line of an answer at a time, after trailing spaces are removed from the line.
- Limits: 8 stages, 4 participants in a stage, 5 rounds in a stage, `max-calls` up to 40.

## Normative Behavior

1. The runner MUST read the block between the first two `---` lines as the header.
2. The runner MUST read each `## ` heading as one stage, in the order of the file.
3. The runner MUST read the `- key: value` lines right under a heading as the settings of that stage.
4. The runner MUST take the rest of a section as the stage prompt, unchanged.
5. WHEN a stage has no `run` setting, the runner MUST use the header `workers` as its participants.
6. WHEN a `run` setting names a role, the runner MUST use the role as the name of that participant.
7. WHEN a `run` setting names lanes, the runner MUST give that participant those checklists and no others.
8. WHEN a stage sets `input` without `from`, the runner MUST take the answers of the stage before it.
9. WHEN a stage has more than one round, the runner MUST take the input of a later round from the round before.
10. WHEN `input` is `own`, the runner MUST insert the participant's own earlier answer.
11. WHEN `input` is `others`, the runner MUST insert the earlier answers of every other participant.
12. WHEN `input` is `all`, the runner MUST insert the earlier answers of every participant and mark the participant's own.
13. The runner MUST replace only the placeholders listed under Surface.
14. The runner MUST NOT execute any part of a pattern file.

## Constraints & Invariants

- Invariant: a pattern holds prompt text and settings only. It names no program, no path to a program and no CLI flag.
- Invariant: worker names and lane names in a pattern are the ones the launcher knows (@.archcore/runtime/polybrief-review.spec.md).
- Constraint: a condition is an expression on the lines of answers or the result of a gate. The format has no variables and no arithmetic.
- Constraint: the stages of a pattern run one after another. Only the participants of one stage run at the same time.
- Constraint: a pattern does not choose the change, the base or the time limit; the caller of the runner does.

## Failure Behavior

1. IF the header lacks `name`, `description` or `workers`, THEN the runner MUST refuse the pattern.
2. IF a header key or a stage setting is unknown, THEN the runner MUST refuse the pattern.
3. IF `from` or `when` names a stage that does not come earlier, THEN the runner MUST refuse the pattern.
4. IF a stage prompt uses `{{input}}` without an `input` setting, THEN the runner MUST refuse the pattern.
5. IF a stage sets `until` with one round, THEN the runner MUST refuse the pattern.
6. IF a stage sets `retry` without `expect`, THEN the runner MUST refuse the pattern.
7. IF a pattern passes a limit listed under Surface, THEN the runner MUST refuse the pattern.
8. IF an expression is not a valid POSIX extended expression, THEN the runner MUST refuse the pattern.
9. IF a pattern has no stage, THEN the runner MUST refuse the pattern.
10. IF the first stage takes `input`, THEN the runner MUST refuse the pattern.
11. IF two participants of one stage share a name, THEN the runner MUST refuse the pattern.
12. IF non-blank text comes before the first stage, THEN the runner MUST refuse the pattern.

## Conformance

A reader is conformant when it satisfies behaviors 1–14 and the failure rules. @tests/test_pattern.sh holds valid patterns for each setting and one invalid pattern for each failure rule. `polybrief plan` reads a pattern and starts no worker, so a pattern can be checked without a model.

```
Given a pattern whose second stage sets input: others and no from
When  the runner reads it
Then  each participant of that stage gets the first stage's answers of the others
```


## Migration note

Imported from `ivklgn-kit/.archcore/codereview/swarm-pattern-file.spec.md`. Historical experiments and verdicts are unchanged; see the Provenance section of `.archcore/architecture/standalone-runtime.adr.md`. The standalone interface adds optional Git context and caller-owned checklists; the extraction ADR defines that change.
