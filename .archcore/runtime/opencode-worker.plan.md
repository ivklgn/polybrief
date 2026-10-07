---
title: "Add OpenCode as a read-only Swarm worker"
status: draft
tags:
  - "polybrief"
---

## Goal

Add OpenCode 1.18.34 as an optional read-only worker through the existing Swarm launcher, with a documented isolation boundary and no Go dependency.

## Declared Delta

- Route: capability, size XL. One new consumer-relied capability: the OpenCode worker.
- Creates: `opencode-worker`. Modifies: none as a separate capability. Retires: none. Decision: isolated CLI profile. Intent gap: no; the new worker serves the existing pattern runtime goal.
- Gap profile: code and Archcore (machine), official OpenCode docs (world), local CLI probes (empirical). Maturity: stone from the accepted Go runtime architecture. Risk: external CLI contract and worker isolation.

## Tasks

### Phase 1 — Settings and command boundary

1. Add the OpenCode worker name, model, variant, and web setting to @config.go and @polybrief.conf.example.
2. Build the isolated OpenCode command and temporary environment in @launch.go.
3. Bridge existing OpenCode credentials into temporary data storage in @launch.go without retaining credential bytes in OUT.
4. Add a one-worker public pattern in `patterns/opencode.md` (removed 2026-10-07; replaced by `-w opencode`).

### Phase 2 — Result mapping and contracts

5. Parse OpenCode text, tool, error, and usage events in @launch.go.
6. Update public help and examples in @main.go, @README.md, and `docs/code-review.md` (removed 2026-10-04).
7. Update contracts in @.archcore/runtime/polybrief-review.spec.md, @.archcore/runtime/polybrief-config.spec.md, @.archcore/runtime/polybrief-cli.spec.md, and @.archcore/runtime/polybrief-reference.doc.md.

### Phase 3 — Verification

8. Add fake-worker checks in @tests/test_review.sh and @tests/test_cli.sh and parser checks in @launch_test.go.
9. Run the four repository checks from @AGENTS.md and inspect the final diff.
10. Recheck the isolated profile through @launch_test.go and record provider results in @.archcore/research/opencode-cli-integration.research.md.

## Acceptance Criteria

- `opencode` can be selected by `-p opencode` or a custom pattern, and by the launcher's `--workers` or `workers` setting; existing default workers remain the same.
- The fake worker observes private HOME/XDG paths, project-config disablement, `--pure`, deny-by-default permissions, and no unrelated caller variable.
- Answer, error, tool, and token fixtures produce the expected worker status and artifacts.
- The four repository checks pass; the reviewed tree remains unchanged in the fake-worker check.

## Dependencies

- Installed OpenCode 1.18.34 for the local configuration probe; fake-worker tests need no model.
- Existing launcher output contract and settings parser in @launch.go and @config.go.
- Provider credentials or an explicit provider environment variable for a later model-backed smoke run.
