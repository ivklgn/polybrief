---
title: "OpenCode worker business requirements"
status: draft
tags:
  - "security"
  - "polybrief"
---

## Mission and Goals

Add OpenCode as a selectable participant in Polybrief's existing read-only pattern runtime. The caller retains ownership of briefs, evidence checks, and final decisions.

## Operational Concept

A caller chooses `opencode` with `-w opencode`, through a pattern that names it, or in a direct launcher call. In a stage without `run:` lines `-w` names the workers; in a stage with `run:` lines it only removes participants. The `workers` setting in the settings file applies only to direct launcher calls. The launcher starts it beside existing workers and reports an answer, status, tool count, and token usage. A missing CLI does not stop other workers.

## Business Requirements

| ID | Requirement | Source |
|---|---|---|
| BRS-OC-1 | The runtime MUST accept OpenCode as an optional worker without changing the default worker set. | Existing worker selection in @config.go |
| BRS-OC-2 | The runtime MUST preserve the read-only profile for an OpenCode worker. | @AGENTS.md and @.archcore/architecture/general-purpose-pattern-runtime.adr.md |
| BRS-OC-3 | The runtime MUST report OpenCode results through the existing worker output contract. | @launch.go |
| BRS-OC-4 | The runtime MUST remain a Go binary with standard-library dependencies only. | @AGENTS.md |

## Business Constraints

- The caller provides a brief and decides whether an answer is useful.
- OpenCode is an optional local CLI dependency. Polybrief installs no provider SDK.
- The current profile permits reading the target tree; no write-capable mode is introduced.
- The OpenCode permission profile is not an OS filesystem sandbox.

## Traceability

| Goal | Requirement IDs |
|---|---|
| Third selectable participant | BRS-OC-1, BRS-OC-3 |
| Existing execution boundary | BRS-OC-2, BRS-OC-4 |

## Clarifications

mode: iso — the OpenCode capability touches worker isolation and secret exposure.
