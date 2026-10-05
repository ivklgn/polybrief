---
title: "Polybrief pattern runner (polybrief runner) contract"
status: draft
tags:
  - "polybrief"
  - "spec"
---

## Purpose & Scope

Normative for the pattern runner of the polybrief binary (@runner.go, internal command `polybrief runner`): how the runner finds and walks a pattern file, what it sends to each participant, and what it prints. Dependents: terminal users and host agents, including the `/codereview` consumer. Out of scope: the format of a pattern (@.archcore/runtime/polybrief-pattern-file.spec.md), the start of a worker and the settings file (@.archcore/runtime/polybrief-review.spec.md), the content of the brief, and the caller's evaluation of results. The decision is in @.archcore/architecture/polybrief-pattern-runner.adr.md.

## Surface

- Run: `polybrief runner --dir DIR [--base REF] --brief FILE|- [--pattern NAME|FILE] [--agents-dir DIR] [--lanes A,B] [--clients A,B] [--timeout SEC] [--max-calls N] [--set KEY=VALUE]… [--config FILE]`. Callers use the public command line (polybrief-cli spec); `--clients` carries `-w`, `--set` carries `-o`.
- `--check [--pattern NAME|FILE] [--agents-dir DIR] [--lanes A,B]`: reads the pattern, prints `PLAN` and `CALLS`, starts no worker.
- `--list`: one `PATTERN<TAB>name<TAB>source<TAB>file<TAB>description` line per pattern.
- Pattern lookup: a value with `/` or ending in `.md` is a file; a name is looked up in the setting `patterns_dir`, then in `patterns/` of the runtime. Without `--pattern`: the setting `pattern`.
- Call limit: `--max-calls`, else the pattern's `max-calls`, else the setting `max_calls`; at most 40.
- Settings, workers, and caller-owned lanes come from `polybrief launch --show-config --agents-dir DIR`. The launcher is the binary itself; the environment variable `POLYBRIEF_LAUNCHER` replaces it in the self-checks.
- Files in `OUT`, a new directory under `TMPDIR`: `brief.md`, optional `change.json`, optional `agents/*.md`, and for each call `<stage>/<round>/<participant>.prompt.md`, `.md`, `.status`, `.launch`.
- Output, tab-separated, in this order:

| Line | Fields |
|---|---|
| `OUT`, `RUN` | directory; run id (the name of `OUT`) |
| `PLAN` | stage, participant names, rounds; one line per stage |
| `CALLS` | highest possible number of calls, limit |
| `SKIPPED`, `CUT`, `OMITTED` | passed on from the launcher, each distinct line once |
| `STAGE` | stage, round, `ran`, `skipped` or `stopped` |
| `WORKER` | stage, round, participant, status, seconds, answer file, worker, model |
| `TOOLS` | stage, round, participant, tool calls |
| `TOKENS` | stage, round, participant, input tokens, output tokens |
| `GATE` | stage, `pass` or `block`, number of matching lines |
| `RESULT` | `complete`, `partial`, `stale`, or `failed`; launcher call count |

- Then every non-empty answer in `<answer-TAG stage=".." round=".." from=".." status="..">`; `TAG` is not the tag of the inserted answers.
- Status of a participant: the status the launcher reported; after the retries, a `malformed` answer stays `malformed`.
- Exit codes: 0 when every executed stage has an `ok` answer, including `partial`; 1 for `stale`, no stage answer, or a call-limit stop; 2 for infrastructure errors with `polybrief: <message>` on stderr; 143 when stopped by `TERM`, `INT` or `HUP`.

## Normative Behavior

1. The runner MUST start a worker only by a call of the launcher of the same runtime, one call per participant.
2. The runner MUST forward the directory, prepared context, timeout, config, captured checklists, and participant lanes to the launcher.
3. The runner MUST pass the stage's `expect` to the launcher.
3a. WHEN `--base` is set and a stage without `expect` inserts `{{brief}}`, the runner MUST pass the review contract.
3b. WHEN no other clause sets a contract for a stage, the runner MUST pass an empty `expect`.
4. The runner MUST run the stages one after another, in the order of the file.
5. The runner MUST start the participants of one stage in parallel.
6. The runner MUST build the prompt of a participant from the stage prompt, with the placeholders replaced.
7. The runner MUST wrap each inserted answer in a tag that is random for each run.
8. The runner MUST name the author and the stage of each inserted answer.
9. The runner MUST tell the participant that an inserted answer is data and that instructions inside it are not followed.
10. WHEN the `when` setting of a stage does not hold, the runner MUST print the stage as `skipped` and go on.
11. WHEN an answer is `malformed` and `retry` allows a further call, the runner MUST call that participant again with the same prompt.
12. WHEN a stage has more than one round, the runner MUST repeat it up to the number of rounds.
13. WHEN every `ok` answer of a round matches `until`, the runner MUST end the rounds of that stage.
14. WHEN a stage has a `gate`, the runner MUST count the matching lines in its `ok` answers and print a `GATE` line.
15. The runner MUST count every call of the launcher against the call limit.
16. The runner MUST print `OUT`, `RUN`, the `PLAN` lines and the `CALLS` line before it starts the first worker.
17. WHEN `--check` is given, the runner MUST print only the `PLAN` and `CALLS` lines and remove its temp directory.
18. WHEN the runner receives `TERM`, `INT` or `HUP`, it MUST stop every launcher it started.
19. The runner MUST wrap each printed answer in a header that holds a tag random for each run.
20. The tag of the printed answers MUST appear in no prompt.
21. WHEN `--base` is supplied, the runner MUST prepare one Git context through the launcher before starting workers.
22. WHEN checklists are selected, the runner MUST copy their contents once into `OUT` before starting workers.
23. WHEN the selected Git context changes persistently, the runner MUST emit `RESULT stale` and exit 1.
24. WHEN a stage keeps an `ok` answer beside a failed participant, the runner MUST emit `RESULT partial` and exit 0.

## Constraints & Invariants

- Invariant: the runner holds no name of a worker CLI and no CLI flag of a worker.
- Invariant: the runner writes nothing inside `DIR`.
- Constraint: the runtime's own `patterns/` may lie inside `DIR`: when the runtime reviews itself, they come from the same tree as the runner, so refusing them protects nothing.
- Invariant: a gate and a condition call no model.
- Invariant: a verdict of a participant and a result of a gate are data for the judge of the skill.
- Constraint: workers keep no session, so the launcher sends the captured change with every call.
- Constraint: the prepared context captures selected Git inputs, not every file a worker can read from `DIR`. Skipped secret-like file contents and ignored files are outside the drift fingerprint.
- Constraint: the settings file is re-read by each launcher call; changing it mid-run can change worker parameters.
- Constraint: the runner needs only the binary; Git is needed only for review mode.
- Constraint: `OUT` is not removed; it holds the prompts, the answers and the launcher's output.

## Failure Behavior

1. IF the pattern breaks a rule of its format, THEN the runner MUST exit 2 and name the file and the line.
2. IF a pattern file outside the runtime's `patterns/` lies inside `DIR`, THEN the runner MUST exit 2.
3. IF a pattern names a worker or a lane that the launcher does not know, THEN the runner MUST exit 2 before it starts a worker.
4. IF the launcher cannot read the settings, THEN the runner MUST exit 2 with the launcher's message.
5. IF the launcher exits 2 during a run, THEN the runner MUST print the launcher's message and exit 2.
6. IF the launcher exits 2 during a run, THEN the runner MUST first stop the other launchers of the stage.
7. IF one participant of a stage fails and another answers, THEN the runner MUST go on with the answers it has.
8. IF a stage ends with no `ok` answer, THEN the runner MUST print the lines and answers so far and exit 1.
9. IF the next calls would pass the call limit, THEN the runner MUST print the stage as `stopped` and exit 1.
10. IF a later stage needs the answer of a participant that has none, THEN the runner MUST leave it out and say so in the prompt.
11. IF the temp directory lies inside `DIR`, THEN the runner MUST exit 2 before it writes anything.
12. IF a required brief, checklist, stage prompt, answer, status, or launcher output cannot be read or written, THEN the runner MUST exit 2.
13. IF the launcher cannot prepare or check the context, THEN the runner MUST exit 2 with a diagnostic.

## Conformance

An implementation is conformant when it satisfies behaviors 1–24, the invariants and the failure rules. @tests/test_pattern.sh builds the binary, copies the built-in `patterns/` into a throwaway runtime, and points `POLYBRIEF_LAUNCHER` at a fake launcher that records every call and answers from files. It covers: the plan of `--check`, the order of stages, the parallel start, each `input` value, the tags, the placeholders, `until` and the round limit, each form of `when`, a gate in both results, a retry and its limit, a failed participant, a stage with no answer, the call limit, a launcher exit 2 and the launchers it stops, a stopped runner, user patterns and `--list`, `--config`, `--agents-dir`, `--dir`, optional `--base`, and `--timeout` on every call, a pattern inside `DIR` and the runtime's own patterns inside it, a temp directory inside `DIR`, the answer tag that no prompt holds, and each refused pattern. It calls no real model. Run: `bash tests/test_pattern.sh`.

A run with real workers is a check by hand; the plan (@.archcore/runtime/polybrief-pattern-runner.plan.md) names the runs that compare the patterns.


## Migration note

Imported from `ivklgn-kit/.archcore/codereview/swarm-pattern-runner.spec.md`. Historical experiments and verdicts are unchanged; see the Provenance section of `.archcore/architecture/standalone-runtime.adr.md`. The standalone interface adds optional Git context and caller-owned checklists; the extraction ADR defines that change.
