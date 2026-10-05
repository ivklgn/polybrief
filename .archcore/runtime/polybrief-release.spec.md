---
title: "polybrief release artifacts and version"
status: draft
tags:
  - "spec"
  - "polybrief"
---

## Purpose & Scope

Normative for what one polybrief release publishes and for the version the binary reports. Dependents: users who download an archive, scripts that fetch assets by URL, users of `go install`, and the ivklgn-kit adapters that call `polybrief` from `PATH`. Out of scope: the maintainer's release procedure (release guide), worker isolation on each OS (polybrief-review spec), and the command line (polybrief-cli spec).

## Surface

- Trigger: a pushed tag `vMAJOR.MINOR.PATCH` without a pre-release suffix; workflow @.github/workflows/release.yml (new).
- Build configuration: @.goreleaser.yaml (new); CI checks: @.github/workflows/ci.yml (new).
- Targets: `linux`, `darwin`, `windows` × `amd64`, `arm64`.
- Assets: `polybrief_<os>_<arch>.tar.gz` for linux and darwin, `polybrief_windows_<arch>.zip`, and `checksums.txt` with one `<sha256>  <asset>` line per archive.
- Archive content: the binary `polybrief` (`polybrief.exe` on windows) at the archive root, plus `README.md`.
- URLs: `https://github.com/ivklgn/polybrief/releases/download/vX.Y.Z/<asset>` and `https://github.com/ivklgn/polybrief/releases/latest/download/<asset>`.
- Version output: `polybrief --version` prints `polybrief <version>` (@main.go).
- Source install: `go install github.com/ivklgn/polybrief@vX.Y.Z`.

## Normative Behavior

1. WHEN a release tag is pushed, the release workflow MUST create one GitHub Release named after the tag.
2. The release workflow MUST attach one archive per target and `checksums.txt` to that release.
3. The release workflow MUST name every archive by the asset pattern under Surface.
4. The release workflow MUST put the sha256 of every archive into `checksums.txt`.
5. The release workflow MUST build every binary with `CGO_ENABLED=0`.
6. The release workflow MUST run gofmt, `go vet` and `go test ./...` before it builds a binary.
7. The release workflow MUST run the three shell checks of @tests/ on linux and darwin before it builds a binary.
8. WHEN the release workflow builds from tag `vX.Y.Z`, the binary MUST print `polybrief X.Y.Z` for `--version`.
9. WHEN a user runs `go install github.com/ivklgn/polybrief@vX.Y.Z`, the installed binary MUST print `polybrief X.Y.Z` for `--version`.
10. WHEN a build carries neither an injected version nor a module version, the binary MUST print `polybrief dev`.

## Constraints & Invariants

- Invariant: a published tag is never moved or reused; a fix ships as the next version.
- Invariant: an archive needs no other file to run, because the built-in patterns are embedded (@runner.go).
- Constraint: the module path stays `github.com/ivklgn/polybrief`; `go install` and the asset URLs depend on it.
- Constraint: the release tooling adds no `require` block to @go.mod (standard-library rule in @AGENTS.md).
- Constraint: @README.md labels the windows assets experimental until the Windows isolation check passes.

## Failure Behavior

1. IF the tag does not match `vMAJOR.MINOR.PATCH`, THEN the release workflow MUST fail before it builds a binary.
2. IF the tag is not the next patch, minor or major version after the highest release tag, THEN the release workflow MUST fail before it builds.
3. IF a check or a target build fails, THEN the release workflow MUST publish no asset.
4. WHEN the publish job runs again after a partial upload, the release workflow MUST replace the existing assets of that release.

## Conformance

An implementation is conformant when it satisfies behaviors 1–10, the invariants and the failure rules. Local check: `goreleaser check` and `goreleaser release --snapshot --clean` list six archives and `checksums.txt` in `dist/`; a Go test covers the version fallback of behaviors 8–10. Release check: the verification steps of the release guide.

Given tag `v0.3.0` is pushed after `v0.2.0`,
When the release workflow finishes,
Then the release lists seven assets and `polybrief_darwin_arm64.tar.gz` holds a `polybrief` that prints `polybrief 0.3.0`.
