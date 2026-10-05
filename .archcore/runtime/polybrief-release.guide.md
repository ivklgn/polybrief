---
title: "Cut a polybrief release"
status: draft
tags:
  - "polybrief"
---

Reader: the maintainer who publishes a new polybrief version. Task: tag a version and confirm that its release assets work. Step actor: the maintainer, at a terminal with push rights to `github.com/ivklgn/polybrief`.

## Prerequisites

- `main` is pushed to `github.com/ivklgn/polybrief`, and the last CI run on `main` passed.
- Go 1.25 and Git are installed; `gh` (GitHub CLI) is logged in for step 7 and the verification.
- The repository contains @.goreleaser.yaml and @.github/workflows/release.yml.

## Steps

1. Run `git switch main && git pull --ff-only`.
2. Run `go test ./... && bash tests/test_review.sh && bash tests/test_pattern.sh && bash tests/test_cli.sh`.
3. Run `git tag --list 'v*' --sort=-v:refname | head -n 1` to see the last release.
4. Pick the next patch, minor or major version; the workflow rejects any other number.
5. Run `git tag -a vX.Y.Z -m "polybrief vX.Y.Z"` with the chosen version.
6. Run `git push origin vX.Y.Z`.
7. Run `gh run watch` and select the Release run for the tag.

## Verification

- `gh release view vX.Y.Z` lists seven assets: six `polybrief_<os>_<arch>` archives and `checksums.txt`.
- On macOS arm64:

```sh
cd "$(mktemp -d)"
gh release download vX.Y.Z -R ivklgn/polybrief -p 'polybrief_darwin_arm64.tar.gz' -p checksums.txt
grep ' polybrief_darwin_arm64.tar.gz$' checksums.txt | shasum -a 256 -c
tar -xzf polybrief_darwin_arm64.tar.gz && ./polybrief --version
```

  Expected: `polybrief_darwin_arm64.tar.gz: OK`, then `polybrief X.Y.Z`.

## Common Issues

- The tag check fails with "does not follow": no release exists yet, so run `git push --delete origin vX.Y.Z` and `git tag -d vX.Y.Z`, then tag the right version.
- The publish job fails during upload: re-run the failed job; GoReleaser replaces the assets that already landed.
- A defect is found after the release is published: do not move the tag; fix it on `main` and release the next patch.
- macOS refuses to open a binary downloaded with a browser: the binary is unsigned; run `xattr -d com.apple.quarantine ./polybrief`.
- Windows SmartScreen blocks `polybrief.exe` on first start: the binary is unsigned; choose "More info", then "Run anyway".
