---
title: "polybrief binary command line"
status: accepted
tags:
  - "spec"
  - "polybrief"
---

## Purpose & Scope

Normative for the public command line of the Go binary `polybrief` (@main.go). Worker isolation is in the launcher spec; pattern syntax and execution are in the pattern specs. The argument-only decision is @.archcore/architecture/arguments-only-runtime.adr.md.

## Surface

- Run: `polybrief [-C DIR] [-b REF] [-p PATTERN] [-c FILE]... [-w LIST] [-o KEY=VALUE]... [--label TEXT] BRIEF|-`
- Plan: `polybrief plan [-p PATTERN] [-c FILE]... [-w LIST] [-o KEY=VALUE]...`
- Patterns: `polybrief patterns`
- Settings: `polybrief config [-o KEY=VALUE]...`
- Yield: `polybrief yield [-o KEY=VALUE]... [--label TEXT] RUN NAME=RAISED/KEPT/ONLY...`
- Help and version: `-h`, `--help`, `--version`, and the words `help` and `version`.
- Internal: `polybrief launch` and `polybrief runner` serve the runner and self-checks.

| Parameter | Value | Default |
|---|---|---|
| `BRIEF` | task file, or `-` for stdin | required, including with `-b` |
| `-C DIR` | directory workers read | current directory |
| `-b REF` | Git base for REF to working-tree change | no Git context |
| `-p PATTERN` | built-in name or Markdown file path | `parallel` |
| `-c FILE` | checklist file, repeatable; name is basename without `.md` | none |
| `-w LIST` | comma-separated `codex`, `claude`, `opencode` | pattern participants |
| `-o KEY=VALUE` | one runtime setting, repeatable | built-in defaults |
| `--label TEXT` | worker log label prefix | pattern name |

- Run output: `OUT`, `RUN`, `PLAN`, `CALLS`, worker results, aggregate `RESULT`, and answer blocks (pattern-runner spec).
- Plan output: `PLAN` lines and `CALLS`; no worker starts.
- Patterns output: `PATTERN<TAB>name<TAB>builtin:name<TAB>description` per built-in pattern.
- Settings output: `CONFIG<TAB>key<TAB>value<TAB>source` per setting, then known workers and lanes.
- Exit codes: 0 complete or partial with an answer in each executed stage; 1 stale, no stage answer, or call limit; 2 infrastructure or input error; 143 stopped.

## Normative Behavior

1. WHEN a run omits `-p`, the binary MUST use the built-in `parallel` pattern.
2. WHEN `-p` names a built-in pattern, the binary MUST read its embedded definition.
3. WHEN `-p` gives a Markdown path, the binary MUST read that file as a custom pattern.
4. WHEN `BRIEF` is `-`, the binary MUST read the brief from stdin until EOF.
5. WHEN `-b` is set, the binary MUST give every worker the selected Git change.
6. WHEN `-b` is set, the binary MUST apply the review answer contract to a stage that inserts `{{brief}}` without its own `expect`.
7. WHEN a pattern names checklists, the binary MUST resolve them only from `-c` files.
8. WHEN a stage names no checklist, the binary MUST give it every `-c` checklist.
9. WHEN `-w` is set, the binary MUST replace workers in stages without `run:` lines and filter workers in stages with `run:` lines.
10. WHEN `-o` is set, the binary MUST pass that setting to the launcher for this command.
11. WHEN a run reaches execution, the binary MUST print `OUT` before starting a worker.
12. WHEN `plan` is called, the binary MUST validate the pattern and settings without starting a worker.
13. WHEN `config` is called, the binary MUST print effective settings and sources.
14. WHEN `yield` is called, the binary MUST append one row per named participant to the effective run log.
15. WHEN help is requested, the binary MUST print usage without starting a worker.
16. The binary MUST start workers only through the launcher.
17. The binary MUST NOT write into `DIR`.

## Constraints & Invariants

- Flags precede the positional brief. One brief is required per run.
- The binary embeds built-in patterns and needs no polybrief home or settings file.
- The caller supplies every brief and checklist. It owns evidence checks and final decisions.
- `-o` setting keys are defined by the runtime-settings spec.

## Failure Behavior

1. IF `BRIEF` is missing or unreadable, THEN the binary MUST refuse the run before starting a worker.
2. IF a flag is unknown, THEN the binary MUST refuse the call.
2b. IF a bare word is not a command word, THEN the binary MUST take it as `BRIEF` and fail with "no such brief" when no such file exists.
2a. IF `-w` is an empty list, THEN the binary MUST refuse the run with exit 2.
3. IF `DIR` does not exist, THEN the binary MUST refuse the run.
4. IF `-b` is set outside a Git work tree or `REF` is not a commit, THEN the binary MUST refuse the run.
5. IF a checklist file is missing or two share a name, THEN the binary MUST refuse the run.
6. IF a pattern names a checklist not supplied by `-c`, THEN the binary MUST refuse the run.
7. IF `-w` names an unknown worker or leaves a stage empty, THEN the binary MUST refuse the run.
8. IF a custom pattern is invalid or lies inside `DIR`, THEN the binary MUST refuse the run.
9. IF `--home` or `--config` is given, THEN the binary MUST reject it as an unknown flag.

## Conformance

@tests/test_cli.sh checks the public command with fake workers and no model quota.