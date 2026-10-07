---
title: "polybrief binary command line"
status: draft
tags:
  - "spec"
  - "polybrief"
---

## Purpose & Scope

Normative for the command line of the Go binary `polybrief` (@main.go): its commands, parameters, inputs, outputs and exit codes. Dependents: host agents, terminal users, and the black-box tests in @tests/; the ivklgn-kit `/codereview` skill is one consumer. Out of scope: the settings file (polybrief-config spec), the pattern format (polybrief-pattern-file spec), worker isolation and optional Git context (polybrief-review spec), stage execution (polybrief-pattern-runner spec).

## Surface

- Run: `polybrief [-C DIR] [-b REF] [-p PATTERN] [-c FILE]... [-w LIST] [-o KEY=VALUE]... [--label TEXT] [--config FILE] BRIEF|-`
- Plan: `polybrief plan [-p PATTERN] [-c FILE]... [-w LIST] [-o KEY=VALUE]... [--config FILE]`
- Patterns: `polybrief patterns [--config FILE]`
- Settings: `polybrief config [-o KEY=VALUE]... [--config FILE]`
- Yield: `polybrief yield [--label TEXT] [--config FILE] RUN NAME=RAISED/KEPT/ONLY...`
- Help and version: `-h`, `--help`, `--version`.
- Internal: `polybrief launch` and `polybrief runner` take the flags of the launcher and runner specs; they serve the runner and the self-checks, not callers.

| Parameter | Value | Default |
|---|---|---|
| `BRIEF` | path of the brief file; `-` reads the brief from stdin | required for a run |
| `-C DIR` | working directory the workers read | current directory |
| `-b REF` | Git base; the change is `REF` to the working tree, untracked files included | none: no Git context |
| `-p PATTERN` | a pattern name, or a path that contains `/` or ends in `.md` | setting `pattern` |
| `-c FILE` | checklist file, repeatable; its name is the file name without `.md` | none |
| `-w LIST` | comma-separated clients `codex`, `claude`, `opencode`: the workers of a stage without `run:` lines, and a filter for the participants of a stage with `run:` lines | none: every pattern participant |
| `-o KEY=VALUE` | one setting override, repeatable | none |
| `--config FILE` | settings file | `$POLYBRIEF_CONFIG`, else the default path |
| `--label TEXT` | run: prefix for worker log labels; yield: label of yield rows | pattern name for runs; none for yield |

- Run output: the runner's tab-separated lines and answer blocks (@.archcore/runtime/polybrief-pattern-runner.spec.md, Surface). A `RESULT` line is present when execution reaches a result; validation and other infrastructure failures may exit before it.
- Plan output: `PLAN<TAB>stage<TAB>participants<TAB>rounds` lines, then `CALLS<TAB>highest<TAB>limit`.
- Patterns output: one `PATTERN<TAB>name<TAB>source<TAB>path<TAB>description` line per available pattern.
- Settings output: `CONFIG_FILE<TAB>path<TAB>loaded|absent`, then one `CONFIG<TAB>key<TAB>value<TAB>source` line per setting.
- Yield output: `LOGGED<TAB>log file<TAB>rows`.
- Version output: `polybrief <version>`.
- Exit codes: 0 every executed stage has an `ok` answer (`RESULT complete` or `partial`); 1 no stage answer, call-limit stop, or source drift; 2 infrastructure failure; 143 stopped by TERM, INT or HUP.

## Normative Behavior

1. WHEN no command word precedes the flags, the binary MUST run the pattern named by `-p`, else by the setting `pattern`.
2. WHEN `BRIEF` is `-`, the binary MUST read the brief from stdin until end of file.
3. WHEN `-b` is set, the binary MUST give every worker the Git change defined in the polybrief-review spec.
4. WHILE `-b` is set, the binary MUST check a stage that inserts `{{brief}}` and sets no `expect` against `^(FINDING|NOT-CHECKED|NO FINDINGS)`.
5. WHEN no contract applies to a stage, the binary MUST report any non-empty successful answer as `ok`.
6. WHEN `-c` is set, the binary MUST give a participant the checklists its `run` line names.
7. WHEN a `run` line names no checklists, the binary MUST give that participant every `-c` checklist.
8. WHEN `-w` is set, the binary MUST run the listed clients in every stage without `run:` lines, in place of the pattern's `workers`, and MUST drop from every other stage the participants whose client is not listed.
9. WHEN `-o` sets a key, the binary MUST use that value over the settings file and the default.
10. The binary MUST print the `OUT` line before it starts any worker.
11. The binary MUST start each worker only with the isolation flags of the polybrief-review spec.
12. WHEN the command is `plan`, the binary MUST validate the pattern and the settings without starting a worker.
13. WHEN the command is `config`, the binary MUST print each effective setting with its source.
14. WHEN the command is `yield`, the binary MUST append one `yield` row per participant to the run log.
15. WHEN `-h` or `--help` is given, the binary MUST print the usage and start no worker.
16. The binary MUST NOT write into `DIR`.
17. WHEN a review run reaches normal, no-answer, call-limit, or drift completion, the binary MUST print one aggregate `RESULT` line from the runner.
18. WHEN the command is `patterns`, the binary MUST list built-in and user patterns without starting a worker.
19. WHEN `--label` is set on a run, the binary MUST use it as the prefix of that run's worker-log labels.
20. WHEN a run uses `-o expect=REGEX`, the binary MUST pass that one-run answer contract to the launcher. This supports a caller-owned challenge without reinstating `expect` in the settings file.

## Constraints & Invariants

- Constraint: flags come before the positional arguments; one `BRIEF` per run.
- Constraint: the binary is self-contained: built-in patterns are embedded, and a run needs only the binary, `git` (for `-b`) and the worker CLIs.
- Invariant: a run writes only to a new directory under `TMPDIR` (`OUT`) and to the run log.
- Invariant: every worker parameter not listed under Surface comes from the settings (polybrief-config spec), never from a dedicated flag.
- Invariant: the public command selects the same pattern, brief, and checklists across host agents and terminals; random prompt tags vary per run.

## Failure Behavior

All failures below exit 2, print `polybrief: <reason>` on stderr and print no `WORKER` line.

1. IF a run has no `BRIEF`, or the brief file does not exist, THEN the binary MUST refuse the run.
2. IF a flag or a command word is unknown, THEN the binary MUST refuse the call.
3. IF `DIR` does not exist, THEN the binary MUST refuse the run.
4. IF `-b` is set and `DIR` is not a Git work tree, THEN the binary MUST refuse the run.
5. IF `REF` does not resolve to a commit, THEN the binary MUST refuse the run.
6. IF a checklist file does not exist, THEN the binary MUST refuse the run.
7. IF two checklists share a name, THEN the binary MUST refuse the run.
8. IF a `run` line names a checklist that no `-c` supplies, THEN the binary MUST refuse the run.
9. IF `-w` names an unknown client, THEN the binary MUST refuse the run.
10. IF `-w` leaves a stage without participants, THEN the binary MUST refuse the run.
11. IF the pattern is unknown or invalid, THEN the binary MUST refuse the run before any worker starts.
12. IF the pattern file or the settings file lies inside `DIR`, THEN the binary MUST refuse the run.
13. IF a `yield` count is not a whole number, THEN the binary MUST refuse the yield.
14. IF required input or output files cannot be read or written, THEN the binary MUST exit 2 with a path-specific diagnostic.

## Conformance

An implementation is conformant when it satisfies behaviors 1–17, the invariants and failure rules 1–14; the black-box tests in @tests/ check them with fake workers. Full command examples are in the polybrief reference doc.

```
Given a Git tree with one change and a brief in review.md
When  polybrief -C repo -b main -c review-tests.md review.md runs
Then  OUT comes first, two WORKER lines follow, and repo is unchanged
```
