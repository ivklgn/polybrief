---
title: "Release polybrief binaries for macOS, Linux and Windows"
status: accepted
tags:
  - "polybrief"
---

## Goal

A pushed `vX.Y.Z` tag publishes working polybrief archives for darwin, linux and windows on amd64 and arm64, as the release spec defines. Windows builds natively and ships as experimental until a check on a real Windows host confirms worker isolation.

## Tasks

### Phase 1 — Version from the tag

1. Replace `const version` with `var version`, set by `-ldflags -X main.version`. Target: @main.go:15.
2. Fall back to `debug.ReadBuildInfo().Main.Version` without `v`, else `dev`. Target: @main.go:49-51.
3. Add one test for the fallback order. Target: @main_test.go (new).
4. Add `dist/` to @.gitignore.

### Phase 2 — Windows build

5. Move `Setpgid` and `stopGroup` into @launch_unix.go (new, `//go:build !windows`). Source: `Setpgid` and `stopGroup` in @launch.go (the code now lives in @launch_unix.go).
6. Add @launch_windows.go: no process group; stop the worker tree with `taskkill /T /F /PID`.
7. Stop the launcher child through the same helper; `Process.Signal(SIGTERM)` fails on Windows. Target: @runner.go:788, @runner.go:969.
8. Read the home directory with `os.UserHomeDir`. Targets: @config.go:52, @config.go:99, @config.go:255, @config.go:277, @launch.go:1094-1097.
9. Use `os.TempDir()` for the temp root. Targets: @main.go:115, @main.go:191, @launch.go:323, @launch.go:584, @runner.go:141, @runner.go:234.
10. Fall back to a copy for checklist links when `os.Symlink` fails. Target: @main.go:211.
11. Fall back to a hard link for the OpenCode `auth.json` link. Target: @launch.go:1101.
12. Pass `SystemRoot`, `PATHEXT`, `ComSpec`, `TEMP`, `TMP` to workers on Windows. Target: @launch.go:768.
13. Give the OpenCode worker private `USERPROFILE`, `APPDATA`, `LOCALAPPDATA` on Windows. Target: @launch.go:1142-1150.
14. Change the @AGENTS.md rule to "isolation flags in `launch.go` and its per-OS files".

### Phase 3 — Release pipeline

15. Create the public repository `github.com/ivklgn/polybrief` and push `main`. Owner action; no target in the tree.
16. Add @.goreleaser.yaml: six targets, `CGO_ENABLED=0`, `-s -w -X main.version`, zip for windows, sha256 checksums, `replace_existing_artifacts`.
17. Add @.github/workflows/ci.yml: gofmt, vet, test on ubuntu, macos, windows; shell checks on ubuntu, macos.
18. Add @.github/workflows/release.yml: tag guard, then `ci.yml` as a called workflow, then `goreleaser release --clean`.
19. Port the tag guard from archcore `scripts/check-release-tag.sh` as one inline step of @.github/workflows/release.yml.
20. Run `goreleaser check` and `goreleaser release --snapshot --clean` locally.
21. Rewrite the Install section: download, checksum, `go install github.com/ivklgn/polybrief@latest`, Windows experimental note. Target: @README.md:14-23.

### Phase 4 — First release

22. Cut the first release with the release guide; the first released tag is `v0.0.1`.
23. Mark task 18 of the Go port plan done by this plan. Target: @.archcore/runtime/go-runtime.plan.md.

### Phase 5 — Windows check

24. On a Windows 11 host, install codex, claude and opencode from their npm or native installers.
25. Run `go test ./...` and one real `parallel` run on a throwaway change.
26. Repeat the E1 isolation probes of the measured runs; check `git status`, user-config loading, and timeout stop.
27. Check that `.cmd` shims of the worker CLIs receive the exact arguments, including `--tools "Read,Grep,Glob"`.
28. Record the results per worker in an `rnd`. Target: @.archcore/research/ (new file).
29. Edit the polybrief-review spec: Windows stop clause and Windows environment names, after the owner confirms. Target: @.archcore/runtime/polybrief-review.spec.md.
30. On pass, remove the experimental note; on failure, mark the failing worker unsupported on Windows. Target: @README.md.

## Status (2026-10-04)

| Phase | Tasks | State |
|---|---|---|
| 1 Version from the tag | 1–4 | done |
| 2 Windows build | 5–14 | code done; all six targets build, `GOOS=windows go vet ./...` passes; runtime behavior unverified (Phase 5) |
| 3 Release pipeline | 15–21 | done; the remote exists (updated 2026-10-08) |
| 4 First release | 22–23 | done; tag `v0.0.1`, `LICENSE` added, install scripts added in commit 5c2c5d9 (updated 2026-10-08) |
| 5 Windows check | 24–30 | open: needs a Windows host |

Checks run on darwin/arm64: `go test ./...` and the three shell checks pass, also under `/bin/bash` 3.2. GoReleaser 2.18.2: `release --snapshot --clean` built six archives and `checksums.txt`; each archive holds the binary and `README.md`; `check` passes in a clone with an `origin` remote and fails without one. The tag guard accepted v0.2.0 as the first tag, then v0.2.1, v0.3.0, v1.0.0, and rejected 0.2.0, v0.2.0-rc1, v0.2.2, v0.4.0, v0.10.0 after v0.2.0.

Departures from the task list:

- Task 8: `homeDir()` (@config.go) reads `$HOME` first, then `os.UserHomeDir`; on Unix this is the old behavior, and on Windows Git Bash's `HOME` and the tests that set `HOME` keep working.
- Tasks 12–13: the Windows names are added in @launch.go under `runtime.GOOS == "windows"`, so the Unix worker environment is unchanged.
- @tests/test_cli.sh now checks the form `polybrief <version>` and that a relocated binary prints the same line, instead of the literal `polybrief 0.2.0`; the value is checked by @main_test.go.
- Added @.gitattributes (`eol=lf`): the Windows runner checks out with `autocrlf`, which would change embedded patterns and test fixtures.
- A plain `go build` from a clone prints a VCS pseudo-version (`polybrief 0.0.0-20261004105800-adff3729f8a0+dirty`), so the release build relies on `-X main.version`.

## Acceptance Criteria

- `GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build .` succeeds, and so do the other five targets.
- `go test ./...` passes on ubuntu, macos and windows runners; the three shell checks pass on ubuntu and macos.
- @go.mod still has no `require` block.
- The shell checks pass unchanged on Unix after Phase 2; no assertion is removed.
- A tag that skips a version fails the workflow, and no release is created.
- Release `v0.0.1` exists, and the guide's verification passes for darwin/arm64 and linux/amd64.
- The Windows `rnd` states a result for each of codex, claude and opencode, and @README.md matches it.

## Dependencies

- A public repository `github.com/ivklgn/polybrief`; the remote exists (2026-10-08).
- GoReleaser v2 through `goreleaser/goreleaser-action@v6` in CI; a local GoReleaser v2 for task 20.
- GitHub-hosted runners `ubuntu-latest`, `macos-latest`, `windows-latest`.
- A Windows 11 host with the worker CLIs for Phase 5; none is available in this session.
- A `LICENSE` file; the tree now has one.
- Phase 3 needs Phase 2, because GoReleaser fails when the windows target does not compile. Phase 5 can run after Phase 4.

## Declared Delta

- Route: capability (size L). Base M from `creates` = 1; raised by M = stone (the accepted Go port decision covers distribution) and R = external-contract (asset names, URLs and the tag scheme become public).
- creates: release-distribution (the polybrief-release spec).
- modifies: launcher on Windows — verdict `spec-wrong` for the polybrief-review spec: clauses 20–21 name only `TERM`/`KILL`, and the Surface environment list has no Windows names (evidence: `Setpgid` and `syscall.Kill` in @launch.go did not compile for windows; now in @launch_unix.go). The spec edit waits for Phase 5 and the owner's confirmation (task 29).
- modifies: settings paths — verdict `code-wrong` against the polybrief-config spec: the spec says `~`, the code reads `$HOME`, which Windows does not set (@config.go:52, @config.go:99). Fixed by task 8.
- retires: none. Task 18 of the Go port plan is discharged by Phase 4.
- decision: release from tags with GoReleaser v2 (release-distribution ADR).
- intent_gap: no — the Go port decision already records "go install and release binaries".
- Π: machine (archcore release files at v0.10.11; cross-build of 2026-10-04); user (three answers in the ADR's Clarifications); empirical (Windows isolation — the spike is Phase 5, because this session has no Windows host).
- Instruments: decision → contract → runbook → decompose. No scenario: the delta has no UI or conversational surface.
