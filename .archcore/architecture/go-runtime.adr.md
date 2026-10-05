---
title: "Port the swarm runtime to a single Go binary"
status: accepted
tags:
  - "architecture"
  - "polybrief"
---

## Context

swarm 0.1.0 is about 900 lines of Bash 3.2 (`scripts/swarm_review.sh`, `scripts/swarm_pattern.sh`, `bin/swarm`), checked by 734 lines of black-box tests with fake workers; its job is a fan-out of 2–8 worker processes with timeouts, process-tree kills and JSON events, and because a worker call takes 66–86 s on average (@.archcore/research/polybrief-measured-runs.rnd.md), orchestration speed does not decide the language. Most defects found so far come from Bash itself — a file named `-` (problem W), names with a newline (N3), `[a-z]` matching capitals in a UTF-8 locale, `08` read as octal, `read` without a final newline under `set -e`, no `timeout(1)` on macOS, JSON only through optional `jq`, `config.toml` read with `sed` (J) — and the planned capability profiles, MCP configuration and base worktree sit in the same area, while the runner already grew to 433 lines against an estimate of 150–250. The CLI also exposes three run commands and 14 run flags where an agent passes five inputs (directory, base, pattern, checklists, brief), and the settings file is a flat list of dotted keys although the worker clients are fixed: `codex` and `claude`. The stack rule in `AGENTS.md` ("Bash 3.2 and Markdown") changes only by a decision.

## Decision

Port swarm to Go as one binary named `swarm`, version 0.2.0.

- Dependencies: the Go standard library only. The settings file and the top-level keys of `~/.codex/config.toml` are read by the binary's own small parsers.
- Distribution: `go install` and release binaries. Built-in patterns are embedded with `go:embed`; an installed binary needs no checkout. The `main` package sits at the module root next to `patterns/`, because `go:embed` cannot reach a parent directory.
- CLI: one run form and three helper commands, as defined in @.archcore/runtime/polybrief-cli.spec.md:
  - `swarm [-C DIR] [-b REF] [-p PATTERN] [-c FILE]... [-w LIST] [-o KEY=VALUE]... BRIEF|-`
  - `swarm plan`, `swarm config`, `swarm yield`.
  - A run without `-p` runs the pattern `parallel`; a run with `-b` adds the Git change.
- Configuration: one section per worker client (`[codex]`, `[claude]`) and top-level general keys, overridable with `-o section.key=value`. Dotted keys stay valid in the file. Defined in @.archcore/runtime/polybrief-config.spec.md.
- Checklists: `-c FILE`, repeatable. A pattern refers to a checklist by its file name without `.md`. `--agents-dir` and `--lanes` go away.
- Pattern format: unchanged (@.archcore/runtime/polybrief-pattern-file.spec.md).
- Built-in patterns: `parallel` (default), `twice`, `panel`, `research`. `refute` leaves the built-in set and becomes an example file: its refuters wrote 0 REFUTED verdicts of 59 (@.archcore/research/polybrief-measured-runs.rnd.md). `parallel` and `twice` carry no `expect` and no `retry`: in 50 measured calls no retry ran.
- Every run is a pattern run. The output is the runner's line set; the launcher's own output form is no longer a public command.
- Answer contract: with `-b`, a stage that inserts `{{brief}}` and sets no `expect` uses `^(FINDING|NOT-CHECKED|NO FINDINGS)`, as `swarm review` did; other stages and runs without `-b` take any non-empty successful answer as `ok`. Later stages answer in their own formats (`VERDICT:`, `POSITION:`), so the contract follows the brief, not the run.
- Unchanged: worker isolation flags, the environment allowlist, secret-name filtering, the runner's output lines, statuses, exit codes, run log columns (@.archcore/runtime/polybrief-review.spec.md, @.archcore/runtime/polybrief-pattern-runner.spec.md).
- Parity gate: the assertions of the existing black-box tests hold for the binary; only the command lines in the tests change to the new surface.
- The Bash scripts are removed once the binary passes the parity gate.

## Alternatives

- Stay on Bash. No build and no dependency. Rejected: the planned features sit where Bash produced most defects, and the runner already outgrew its estimate.
- Python. Good standard library (`subprocess`, `json`, `tomllib` from 3.11). Rejected: the system Python on macOS is 3.9.6 without `tomllib`, so users need a runtime install; crewplane needed Python 3.13 on the same machine.
- Rust. One binary, like Go. Rejected: more code and a slower build for the same fan-out of processes; no measured gain (consult-llm, written in Rust, did not differ from other tools).
- Node or TypeScript. Rejected: a runtime dependency that the `claude` CLI no longer needs.
- Keep the wide CLI with one flag per setting. Rejected: agents pass five inputs; the rest belongs to the user's settings.
- Worker spec strings such as `codex:gpt-6-sol@high`. Rejected: harder to read and to report errors in; running one client twice is already done with pattern roles.

## Consequences

- `AGENTS.md` changes its stack line to Go and its checks to `go test ./...` plus the black-box tests.
- @.archcore/runtime/cli.spec.md is replaced by @.archcore/runtime/polybrief-cli.spec.md. The Surface sections of the launcher and runner specs change from script flags to the binary; their behavior clauses stay.
- Releases need a build step. Consumers no longer need a checkout, `SWARM_ROOT`, `jq`, `pgrep` or Bash 3.2. `TOOLS` and `TOKENS` lines no longer depend on `jq`.
- The ivklgn-kit adapters call `swarm` from `PATH`; the kit owns that change and its `references/swarm.md`. A kit step that read the launcher's `WORKER<TAB>name<TAB>status…` lines reads the runner's lines instead.
- The settings-file key `expect` loses its use: the normal answer contract comes from the pattern or from `-b`. A caller may set `-o expect=REGEX` for a one-run challenge protocol; the file key remains ignored.
- Existing `swarm.conf` files keep working, because dotted keys stay valid.
- A user who relied on the built-in `refute` copies the example file into `~/.config/swarm/patterns/`.
- The migration steps are in @.archcore/runtime/go-runtime.plan.md.

## Consumer compatibility additions

The ivklgn-kit cutover keeps its existing shell entry points while they translate
to the public Go CLI. `swarm patterns` exposes the available-pattern list, and
run-level `--label` keeps lane and challenge labels in worker logs. Both are
read-only helper surface; the kit still owns the briefs, selected checklists,
evidence checks, and final verdict.
