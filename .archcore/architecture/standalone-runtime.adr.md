---
title: "Extract swarm as a standalone read-only runtime"
status: accepted
tags:
  - "architecture"
  - "polybrief"
---

## Context

The source kit held 856 lines of worker and pattern execution code, runtime self-checks, and nine swarm documents. The user requested extraction to `../swarm` while keeping codereview as a consumer; the Provenance section below records the source revision and document paths.

## Decision

Publish a local standalone Bash CLI, swarm 0.1.0, with generic briefs, optional Git review context, and caller-owned checklists.

## Alternatives Considered

- Keeping swarm inside ivklgn-kit was rejected because runtime development would remain coupled to the plugin.
- Keeping engine copies in both projects was rejected because isolation flags and behavior would have two owners.
- Replacing the engine with counselors or taskflow was deferred because the extraction preserves the implementation already exercised by the imported self-checks.

## Consequences

- Positive: `bin/swarm` runs without the kit; `tests/` uses its own checklist fixtures and fake workers.
- Positive: generic `run` and `pattern` accept a non-Git directory; `--base` adds the existing review context.
- Positive: the kit keeps its checklists and judge while calling this runtime through compatibility adapters.
- Boundary: swarm has no dependency on the kit checkout. The kit consumes the public CLI through PATH or an explicit `SWARM_ROOT`; automatic sibling discovery is forbidden. Each project owns its own tests; a separate consumer integration check requires the installed CLI.
- Tradeoff: review mode remains part of the launcher in this first extraction; further separation of context preparation is deferred.
- Tradeoff: new default settings and logs use the `swarm` namespace; legacy config selection belongs to the kit adapter.
- History: nine documents and their internal relations are imported; historical measurements are not rerun benchmarks.

## Superseded when

Revisit when two consumers require different context builders, or one consumer requires write-capable workers.

## Provenance

Source: local `ivklgn-kit` repository, clean working tree at commit `3d319fc1ee22c38db642f6fb5ab6a9f48619a0ae`. No remote was created; the original history remains in that repository.

| Original path | New path |
|---|---|
| `.archcore/codereview/swarm-pattern-file.spec.md` | `.archcore/runtime/polybrief-pattern-file.spec.md` |
| `.archcore/codereview/swarm-pattern-layer.rnd.md` | `.archcore/research/polybrief-pattern-layer.rnd.md` |
| `.archcore/codereview/swarm-pattern-runner.adr.md` | `.archcore/architecture/polybrief-pattern-runner.adr.md` |
| `.archcore/codereview/swarm-pattern-runner.plan.md` | `.archcore/runtime/polybrief-pattern-runner.plan.md` |
| `.archcore/codereview/swarm-pattern-runner.spec.md` | `.archcore/runtime/polybrief-pattern-runner.spec.md` |
| `.archcore/codereview/swarm-review-engine.rnd.md` | `.archcore/research/polybrief-review-engine.rnd.md` |
| `.archcore/codereview/swarm-review-findings.doc.md` | `.archcore/research/polybrief-review-findings.doc.md` |
| `.archcore/codereview/swarm-review.spec.md` | `.archcore/runtime/polybrief-review.spec.md` |
| `.archcore/codereview/ultraswarm-optional-engine.adr.md` | `.archcore/architecture/ultraswarm-optional-engine.adr.md` |

Runtime code came from `skills/codereview/scripts/swarm_*.sh`, self-checks from `test_swarm_*.sh`, presets from `skills/codereview/patterns/`, and settings from `swarm.conf.example`. Imported research keeps the reported measurements and conclusions; rebased paths and migration notes identify the new owner. Consumer rules and prompts remain in ivklgn-kit. Cross-project references are prose references, not Archcore relations. The new paths include the 2026-10-04 rename (@.archcore/architecture/polybrief-rename.adr.md).
