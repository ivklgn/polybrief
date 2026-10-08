---
title: "Port swarm to a single Go binary"
status: accepted
tags:
  - "architecture"
  - "polybrief"
---

## Goal

Replace the Bash runtime with the Go binary `swarm` 0.2.0 that meets the swarm-cli and swarm-config specs, keeps the launcher and runner behavior, and passes the existing black-box assertions. The Bash scripts are deleted at the end.

## Tasks

### Phase 1 — Module and settings

1. Create the module, `swarm --version` and `-h`. Targets: @go.mod (new), @cmd/swarm/main.go (new).
2. Write the settings reader: sections, dotted keys, `-o`, `-w`, sources, and the top-level reader of Codex `config.toml`. Targets: @internal/config/ (new); source of today's rules: the settings part of @scripts/swarm_review.sh.
3. Add the `swarm config` command. Target: @cmd/swarm/main.go.
4. Write Go tests for the settings reader. Target: @internal/config/config_test.go (new).
5. Change the stack line and the checks in @AGENTS.md to Go.

### Phase 2 — Launcher core

6. Port the Git change: diff, untracked files, secret names, cut, history. Targets: @internal/change/ (new); source: @scripts/swarm_review.sh.
7. Port the worker start: commands, environment allowlist, process group, timeout, signals. Targets: @internal/worker/ (new); source: @scripts/swarm_review.sh.
8. Port statuses, `TOOLS` and `TOKENS` from JSON events, and the run log. Targets: @internal/worker/, @internal/runlog/ (new).
9. Point the assertions of @tests/test_review.sh at the binary; change only command lines.

### Phase 3 — Runner and patterns

10. Port the pattern reader and the plan. Targets: @internal/pattern/ (new); source: @scripts/swarm_pattern.sh.
11. Port stage execution, `-w` filtering and the implicit review contract. Target: @internal/pattern/.
12. Embed @patterns/ with `go:embed`; add @patterns/twice.md; remove `expect` and `retry` from @patterns/parallel.md; move `refute` out of the built-in patterns (the example file was deleted later).
13. Add `swarm plan` and `swarm yield`. Target: @cmd/swarm/main.go.
14. Point @tests/test_pattern.sh and @tests/test_cli.sh at the binary; change only command lines.

### Phase 4 — Cutover

15. Delete @bin/swarm, @scripts/swarm_review.sh, @scripts/swarm_pattern.sh and @scripts/install.sh.
16. Rewrite the example settings file in sections (the settings file was removed later, see @.archcore/architecture/arguments-only-runtime.adr.md); update @README.md and `docs/code-review.md` (removed 2026-10-04) to the new usage.
17. Run each built-in pattern once with real workers on a throwaway change.
18. Publish release binaries for darwin and linux, arm64 and amd64. Done by @.archcore/runtime/polybrief-release.plan.md: the remote exists and the first tag is `v0.0.1`.

### Phase 5 — Contracts and consumer

19. Change the Surface sections of the swarm-review and swarm-pattern-runner specs from script flags to the binary.
20. Mark the old CLI spec as replaced by the swarm-cli spec in the relation graph.
21. Repeat the isolation probes E1 of the measured runs on the binary.
22. In ivklgn-kit: translate the existing adapters to the public Go `swarm` CLI, pass selected checklists with `-c`, and read the runner's lines. The kit owns the change.

## Status (2026-10-01)

| Phase | Tasks | State |
|---|---|---|
| 1 Module and settings | 1–5 | done |
| 2 Launcher core | 6–9 | done |
| 3 Runner and patterns | 10–14 | done |
| 4 Cutover | 15–18 | done; 18 closed by the release plan (tag `v0.0.1`) |
| 5 Contracts and consumer | 19–22 | done; task 22 implemented in ivklgn-kit, with adapter and Go binary integration checks |

Departures from the task list:

- Layout: one `main` package at the module root (@main.go, @config.go, @launch.go, @runner.go, @config_test.go) instead of `cmd/swarm/` and `internal/`: `go:embed` cannot reach `patterns/` from a subdirectory.
- The runner starts the launcher as a child process (`swarm launch`), as the Bash runtime did; `SWARM_LAUNCHER` lets @tests/test_pattern.sh keep its fake launcher.
- Test changes beyond command lines: @tests/test_pattern.sh took `refute` from an example file (deleted later) and checks `retry` with its own pattern, because `parallel` lost `retry`; @tests/test_cli.sh is rewritten for the public command line.
- The implicit review contract applies only to stages that insert `{{brief}}`: applied to every stage, it marked the `POSITION:` answers of a multi-stage pattern malformed.
- Size: 2310 lines of Go with gofmt, against an estimate of 1000–1500.

Real runs on 2026-10-01 (change c5): `parallel`, `twice`, `panel` and `research` (now `crosscheck`, renamed in commit 130423a) each exited 0 and left the tree unchanged; the slowest worker took 528 s. The E1 probe: the Codex worker printed no `AGENTS.md` canary.

## Acceptance Criteria

- `go test ./...` passes, and @go.mod has no `require` block.
- The three black-box test files pass against the binary; their diff against commit `c5db1fc` changes command lines only and removes no assertion.
- `go install` from a clean clone gives a working `swarm`, and a run succeeds after the clone is deleted.
- No file remains under @scripts/ or @bin/.
- A real run of `parallel`, `twice`, `panel` and `research` (now `crosscheck`) on one change exits 0, and `git status` of the reviewed tree is unchanged.
- The repeated E1 probes give the same results as on 2026-09-29: the Codex worker does not follow an `AGENTS.md` of the tree.
- The owner's current `~/.config/swarm/swarm.conf` gives the same values in `swarm config` as in the 0.1.0 `--show-config`.

## Dependencies

- The decision and the two new specs on this topic; the pattern-file spec as updated on 2026-10-01.
- Go 1.25 (installed: go1.25.10, darwin/arm64).
- Worker CLIs whose flags were checked: codex-cli 0.159.0, Claude Code 2.1.284.
- Phase 2 needs Phase 1: the launcher reads its settings from the new reader.
- Phase 4 needs Phases 2 and 3 to pass their test files.
- Task 18 needed a remote repository (now exists). Task 22 was completed in ivklgn-kit.

## Declared Delta

- Route: the `sdd` path named in the request — intent, a contract per capability, decomposition. The intent step closed through the compression path: the accepted decision records the problem and the goals, so no prd was written.
- creates: swarm-cli (command line), swarm-config (settings), swarm-reference (examples doc).
- modifies: swarm-pattern-file (lookup and checklist naming, example moved to the doc); swarm-review and swarm-pattern-runner (Surface only, task 19).
- retires: the Bash entry point and its spec, @scripts/swarm_review.sh, @scripts/swarm_pattern.sh, @scripts/install.sh, the built-in `refute`.
- decision: port to Go, accepted on 2026-10-01.
- intent_gap: no.
- Rationale: the behavior contracts of the launcher and runner stay; only the surface, the settings form and the language change, so the package is two new contracts plus a plan, and the existing contracts change at cutover rather than now, to keep them true for the Bash code until it is deleted.
