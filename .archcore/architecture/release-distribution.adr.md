---
title: "Release polybrief from version tags with GoReleaser"
status: draft
tags:
  - "architecture"
  - "polybrief"
---

## Context

The Go port decision promised "`go install` and release binaries", but task 18 of the Go port plan is still open: the repository has no remote and no tag, and the version is the constant `0.2.0` in @main.go. A cross-build on 2026-10-04 (go1.25.10, `CGO_ENABLED=0`) produced binaries for darwin and linux on amd64 and arm64. It failed for windows, because `Setpgid` (@launch.go:849) and `syscall.Kill` (@launch.go:1029-1036) exist only on Unix. Archcore CLI already publishes the same six targets from `v*` tags with GoReleaser v2 (`cli/.goreleaser.yaml` and `.github/workflows/release.yml` in archcore, releases v0.10.7–v0.10.11), and the owner asked for the same release flow for polybrief.

## Decision

A pushed `vMAJOR.MINOR.PATCH` tag in the public repository `github.com/ivklgn/polybrief` runs a GitHub Actions workflow that tests the tree and then runs GoReleaser v2, which attaches `tar.gz` archives for linux and darwin, `zip` archives for windows (each for amd64 and arm64) and a sha256 `checksums.txt` to a GitHub Release, with the tag injected as the binary version.

## Scope of the decision

- Windows is a native target. The process-tree stop and the path code move to per-OS files next to @launch.go. Windows stays marked experimental in @README.md until a check on a real Windows host confirms the read-only isolation of each worker.
- Archives only: no install scripts, no package manager. @README.md gives the download, checksum and `go install github.com/ivklgn/polybrief@latest` commands.
- GoReleaser runs only in CI. @go.mod gets no `require` block, so the standard-library rule in @AGENTS.md still holds.
- A tag guard (as in archcore `scripts/check-release-tag.sh`) accepts only the next patch, minor or major version.

## Alternatives Considered

1. A shell loop of `GOOS=… GOARCH=… go build` plus `gh release create` in the workflow — rejected because the owner asked for parity with archcore, and GoReleaser already covers archive names, checksums, the changelog and re-run convergence (`replace_existing_artifacts`) in one config file that archcore has used for five releases.
2. `install.sh` and `install.ps1` attached to each release, as archcore does — rejected because the owner chose archives only on 2026-10-04; the archcore scripts are 582 and 645 lines, mostly telemetry and plugin setup that polybrief does not use.
3. Windows through WSL only (linux archives) — rejected because the owner wants native Windows archives.
4. A Homebrew tap from GoReleaser — deferred because it needs a second repository and a token with write access.
5. A private repository — rejected because anonymous downloads and `go install` need a public module path.

## Consequences

Positive:

- [expected] A user on darwin, linux or windows (amd64 or arm64) runs polybrief without a Go toolchain or a checkout; the built-in patterns are embedded.
- `polybrief --version` reports the tag version for release builds and for `go install …@vX.Y.Z`.

Negative and trade-offs:

- The @AGENTS.md rule "worker startup and isolation flags in `launch.go`" extends to `launch_unix.go` and `launch_windows.go`, because `Setpgid` does not compile on Windows.
- [assumption] On Windows the timeout stop is `taskkill /T /F`: there is no five-second grace period between `TERM` and `KILL`, so a worker cannot finish writing its answer.
- [assumption] On Windows, Node- and Bun-based CLIs read `USERPROFILE` and `APPDATA` rather than `HOME`, so the private-HOME isolation of the OpenCode worker may not hold until those names are overridden and checked.
- The shell checks in @tests/ use extensionless fake workers that Windows `exec.LookPath` cannot find, so Windows CI runs `go vet` and `go test` only.
- Release binaries are unsigned: macOS quarantines a browser download, and Windows SmartScreen warns on first start.

## Superseded when

- A Windows host check shows that a worker CLI cannot be kept read-only on Windows: then that worker is marked unsupported on Windows, or the windows targets are dropped.
- Two or more users ask for an installer or a package manager (Homebrew, Scoop, winget).
- polybrief needs CGO, which ends the single cross-compiled build per target.

## Clarifications

- Windows support (2026-10-04): native build plus a verification phase; experimental until verified.
- Repository (2026-10-04): public `github.com/ivklgn/polybrief`, matching the module path in @go.mod.
- Install channels (2026-10-04): archives and `checksums.txt` only.
