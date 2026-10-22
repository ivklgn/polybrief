---
title: "Polybrief pattern runner (polybrief runner) contract"
status: accepted
tags:
  - "polybrief"
  - "spec"
---


## Purpose & Scope

Normative for the pattern runner of the polybrief binary (@runner.go, internal command `polybrief runner`): how the runner finds and walks a pattern file, what it sends to each participant, and what it prints. Dependents: terminal users and host agents, including the `/codereview` consumer. Out of scope: the format of a pattern (@.archcore/runtime/polybrief-pattern-file.spec.md), the start of a worker and runtime settings (@.archcore/runtime/polybrief-review.spec.md), the content of the brief, and the caller's evaluation of results. The decision is in @.archcore/architecture/polybrief-pattern-runner.adr.md.

## Surface

- Run: `polybrief runner --dir DIR [--base REF] --brief FILE|- [--pattern NAME|FILE] [--agents-dir DIR] [--lanes A,B] [--clients A,B] [--timeout SEC] [--max-calls N] [--label TEXT] [--set KEY=VALUE]…`. Callers use the public command line (polybrief-cli spec); `--clients` carries `-w`, `--set` carries `-o`, `--label` is the label written to the run log.
- `--check [--pattern NAME|FILE] [--agents-dir DIR] [--lanes A,B] [--clients A,B] [--set KEY=VALUE]…`: reads the pattern, prints `PLAN` and `CALLS`, starts no worker.
- `--list`: one `PATTERN<TAB>name<TAB>builtin:name<TAB>description` line per embedded pattern.
- Pattern lookup: a value with `/` or ending in `.md` is a caller-owned file; a name is an embedded pattern. Without `--pattern`: embedded `parallel`.
- Call limit, first that is set wins: the internal `--max-calls`; `-o max_calls` when given explicitly (source `flag`); the pattern's `max-calls`; the built-in default 12. At most 40.
- Settings, workers, and caller-owned lanes come from `polybrief launch --show-config --agents-dir DIR` with forwarded `--set` arguments. The launcher is the binary itself; the environment variable `POLYBRIEF_LAUNCHER` replaces it in the self-checks.
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
2a. WHEN a participant runs `at base`, the runner MUST forward the base tree as its directory and no prepared context.
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
25. WHEN a pattern has a participant `at base`, the runner MUST resolve `--base` to one commit before it prepares the Git context.
26. WHEN a pattern has a participant `at base`, the runner MUST unpack that commit's tree with `git archive` into a new directory `polybrief-base.*` under `TMPDIR`.
26a. WHEN the runner unpacks the base tree, it MUST create the links after every file and directory.
26c. WHEN the runner unpacks the base tree, it MUST NOT create a path outside the base tree.
26b. WHEN two names of the base tree differ only in case and the filesystem ignores case, the runner MUST keep the first and go on.
27. The runner MUST make the base tree an empty Git repository, with no commit and no history of `DIR`.
27a. WHEN the runner makes the base tree a Git repository, it MUST run `git init` without the caller's `GIT_*` variables.
28. WHEN the run ends, exits 2 or receives a stop signal, the runner MUST remove the base tree, also while it is being unpacked.

## Constraints & Invariants

- Invariant: the runner holds no CLI flag of a worker and starts no worker CLI itself. It knows worker names only to check that OpenCode has `opencode.model` before any call (@runner.go).
- Invariant: the runner writes nothing inside `DIR`.
- Constraint: embedded patterns may be used while reviewing the runtime itself. A custom pattern file inside `DIR` is refused.
- Invariant: a gate and a condition call no model.
- Invariant: a verdict of a participant and a result of a gate are data for the judge of the skill.
- Constraint: workers keep no session, so the launcher sends the captured change with every call.
- Constraint: the prepared context captures selected Git inputs, not every file a worker can read from `DIR`. Skipped secret-like file contents and ignored files are outside the drift fingerprint.
- Constraint: each launcher call receives the run's argument overrides; there is no polybrief settings file.
- Constraint: the runner needs only the binary; Git is needed only for review mode.
- Constraint: `OUT` is not removed; it holds the prompts, the answers and the launcher's output.
- Constraint: the base tree holds what `git archive` gives: files marked `export-ignore` and submodule contents are missing, and links the system refuses or whose path would leave the tree are skipped. `git archive` itself refuses a tree with a `.git` entry.
- Constraint: a participant `at base` is kept from the change by its directory and its prompt, not by a sandbox; a read-only worker can still read other paths on the machine.

## Failure Behavior

1. IF the pattern breaks a rule of its format, THEN the runner MUST exit 2 and name the file and the line.
2. IF a custom pattern file lies inside `DIR`, THEN the runner MUST exit 2.
3. IF a pattern names a worker or a lane that the launcher does not know, THEN the runner MUST exit 2 before it starts a worker.
4. IF the launcher rejects a setting, THEN the runner MUST exit 2 with the launcher's message.
5. IF the launcher exits 2 during a run, THEN the runner MUST print the launcher's message and exit 2.
6. IF the launcher exits 2 during a run, THEN the runner MUST first stop the other launchers of the stage.
7. IF one participant of a stage fails and another answers, THEN the runner MUST go on with the answers it has.
8. IF a stage ends with no `ok` answer, THEN the runner MUST print the lines and answers so far and exit 1.
9. IF the next calls would pass the call limit, THEN the runner MUST print the stage as `stopped` and exit 1.
10. IF a later stage needs the answer of a participant that has none, THEN the runner MUST leave it out and say so in the prompt.
11. IF the temp directory lies inside `DIR`, THEN the runner MUST exit 2 before it writes anything.
12. IF a required brief, checklist, stage prompt, answer, status, or launcher output cannot be read or written, THEN the runner MUST exit 2.
13. IF the launcher cannot prepare or check the context, THEN the runner MUST exit 2 with a diagnostic.
14. IF a run has a participant `at base` and no `--base`, THEN the runner MUST exit 2 before it creates `OUT`.
14a. IF `--check` reads a pattern with a participant `at base`, THEN the runner MUST NOT require `--base`.
15. IF the base cannot be resolved or its tree cannot be unpacked, THEN the runner MUST exit 2 before it starts a worker.

## Conformance

An implementation is conformant when it satisfies behaviors 1–28, the invariants and the failure rules. @tests/test_pattern.sh builds the binary and points `POLYBRIEF_LAUNCHER` at a fake launcher that records every call and answers from files. It covers: the plan of `--check`, the order of stages, the parallel start, each `input` value, the tags, the placeholders, `until` and the round limit, each form of `when`, a gate in both results, a retry and its limit, a failed participant, a stage with no answer, the call limit, a launcher exit 2 and the launchers it stops, a stopped runner, an explicit custom pattern and `--list`, `--set`, `--agents-dir`, `--dir`, optional `--base`, and `--timeout` on every call, a pattern inside `DIR`, a temp directory inside `DIR`, the answer tag that no prompt holds, each refused pattern, a crafted base tree (a link and a directory of one name, two names that differ only in case), and a stop signal while the base tree is unpacked. It calls no real model. Run: `bash tests/test_pattern.sh`. @tests/test_cli.sh runs task-fit checks through `parallel` with `-o expect=…` and fake workers: both workers get the task, the spec and the diff; a row answer is `ok`, and the same answer is `malformed` without the override. It executes the copied done-check skill's launch block, runs the caller-owned panel example, and checks that only `parallel`, `twice` and `crosscheck` are embedded. It also runs a custom pattern with a participant `at base`: that participant runs in the base tree that holds the base commit's files and no history, gets the task and no diff; the others get the diff; the judge gets both answers, the task, the spec and the diff; the base tree is gone after the run; a run without `-b` is refused before `OUT` and `plan` is not; an unknown base is refused before any worker.

A run with real workers is a check by hand; the measured runs that compare the patterns are in @.archcore/research/polybrief-measured-runs.rnd.md.


## Migration note

Imported from `ivklgn-kit/.archcore/codereview/swarm-pattern-runner.spec.md`. Historical experiments and verdicts are unchanged; see the Provenance section of `.archcore/architecture/standalone-runtime.adr.md`. The standalone interface adds optional Git context and caller-owned checklists; the extraction ADR defines that change.
