---
title: "Keep detailed Polybrief documentation in Archcore"
status: accepted
tags:
  - "architecture"
  - "polybrief"
---

## Context

@README.md previously linked two pages under `docs/`, while the same CLI and pattern contracts already lived in `.archcore/`. Those public pages repeated command syntax and pattern guidance from the existing Archcore reference. The user chose one documentation home with a short README for ordinary use.

## Decision

Keep detailed Polybrief reference and pattern guidance in `.archcore/runtime/`, keep copyable skills in @examples/, and leave only concise usage in @README.md; remove the root `docs/` directory.

## Alternatives Considered

1. Keep `docs/` beside `.archcore/` — rejected because the CLI syntax and pattern guidance then require updates in two documentation trees.
2. Move every detail into `README.md` — rejected because the README would combine quick start, diagrams, settings, safety limits, and historical measurements in one page.

## Consequences

- [expected] One internal documentation tree holds detailed reference material and the contracts it explains.
- [expected] The README keeps installation, first commands, examples, diagrams, and a short command reference.
- [expected] Readers seeking detailed settings or pattern syntax must open `.archcore/`, which is included in the source repository but not in the release archive.

## Superseded when

- Revisit if release archives add a complete offline manual beyond `README.md`.
- Revisit if two user reports in one release cycle ask for detailed public docs outside the source repository.