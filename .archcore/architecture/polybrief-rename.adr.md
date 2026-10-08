---
title: "Rename swarm to polybrief"
status: accepted
tags:
  - "polybrief"
---

## Context

The binary was named `swarm`. The runtime gives one caller brief to several read-only agent CLIs and walks a fixed Markdown pattern; the caller judges the answers (@.archcore/architecture/general-purpose-pattern-runtime.adr.md). Nothing emerges from worker interaction, so the name promised a mechanism the runtime does not have. The same ADR already rejected positioning the product as a self-organizing agent swarm.

On 2026-10-04 the project had no public GitHub repository, no tags and no releases (`gh release list -R ivklgn/swarm`: repository not found; `git tag`: empty), so a rename broke no published URL, archive name or `go install` path.

## Decision

The project, binary, Go module, settings and state namespaces are named `polybrief`: one brief, several workers.

- Binary and module: `polybrief`, `github.com/ivklgn/polybrief`; release archives `polybrief_<os>_<arch>`.
- Settings: `~/.config/polybrief/polybrief.conf`, `~/.config/polybrief/patterns/`; log `~/.local/state/polybrief/polybrief-runs.tsv`. Note: the settings paths `~/.config/polybrief/...` no longer exist; superseded by @.archcore/architecture/arguments-only-runtime.adr.md.
- Environment: every `SWARM_*` variable became `POLYBRIEF_*`; the OpenCode agent is `polybrief-readonly`; temporary directories use the `polybrief-` prefix.
- Files: Archcore documents `swarm-*.md` became `polybrief-*.md`, with relations updated; the shell checks became `tests/test_review.sh` and `tests/test_pattern.sh`, next to `tests/test_cli.sh`.
- Records of past work keep their prose: imported ivklgn-kit research, finished plans, accepted or rejected decisions, the superseded Bash CLI spec, and the extraction provenance (now in @.archcore/architecture/standalone-runtime.adr.md). The raw run data under `research/` and the ported Russian guide `docs/code-review.md` were removed from the tree on 2026-10-04 (last present in commit `274ed53`). Only their links to renamed files changed. There, `swarm` names the tool or the kit's `/codereview` depth as it was called at the time.
- External names stay: `ultraswarm`, `metaswarm`, ivklgn-kit paths and scripts (`references/swarm.md`, `swarm_review.sh`), the kit's `/codereview swarm` mode, and the old bench data under `~/.local/state/swarm/`.
- The runner no longer strips the legacy `swarm_review.sh: ` prefix; the fake launcher in @tests/test_pattern.sh now prints `polybrief: `.

## Alternatives

- Keep `swarm`. Rejected: the name describes emergent coordination, which the runtime does not do.
- Council-style names (`council`, `veche`, `synod`, `concilium`, `consortium`). Rejected: taken by multi-LLM tools on GitHub (for example karpathy/llm-council, cyberash-dev/veche), and they promise deliberation and a verdict that the caller owns here.
- Descriptive `ask` names (`askall`, `askaround`). Free on GitHub, npm and PyPI, but they tie the name to asking, while write-capable workflows remain a future capability. Kept as candidates if `polybrief` proves unclear.
- No compatibility fallback for `SWARM_*` variables or `~/.config/swarm/`: there were no public users, and the owner had no `~/.config/swarm/` on 2026-10-04.

## Consequences

- ivklgn-kit adapters that call `swarm` from `PATH`, or set `SWARM_*` variables, need the kit owner to switch to `polybrief` and `POLYBRIEF_*`.
- Searches of `.archcore/` for the old name still find the historical records; current contracts use only `polybrief`.
- The local checkout directory is still named `swarm`; renaming it is outside the repository.
- Verified on 2026-10-04: `go test ./...`, `bash tests/test_review.sh`, `bash tests/test_pattern.sh` and `bash tests/test_cli.sh` pass after the rename.