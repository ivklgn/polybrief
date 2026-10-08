---
title: "OpenCode worker stakeholder requirements"
status: accepted
tags:
  - "security"
  - "polybrief"
---

## Stakeholder Classes

- Caller: selects workers and evaluates the returned answer.
- Operator: configures local models, credentials, and optional environment variables.
- Reviewer: checks that the target tree and worker artifacts obey the read-only contract.

## Concept of Operations

The caller selects `opencode`. The operator may set a provider/model and variant. The launcher prepares the prompt, starts the CLI, records its JSON events, and returns status without making a final decision.

## Stakeholder Requirements

| ID | Requirement | Parent |
|---|---|---|
| STRS-OC-1 | WHEN a caller selects OpenCode, the launcher MUST give it the same prepared brief as the other workers. | BRS-OC-1 |
| STRS-OC-2 | WHEN OpenCode finishes, the launcher MUST expose its answer and status through the existing output format. | BRS-OC-3 |
| STRS-OC-3 | WHEN an operator supplies a model or variant, the launcher MUST pass that choice to OpenCode. | BRS-OC-1 |
| STRS-OC-4 | WHILE OpenCode runs, the launcher MUST restrict its enabled tools to the read-only profile. | BRS-OC-2 |
| STRS-OC-5 | IF OpenCode is absent, THEN the launcher MUST report missing and continue other workers. | BRS-OC-3 |
| STRS-OC-6 | WHEN the operator has a stored OpenCode login, the launcher MUST let the worker use it without copying it into worker artifacts. | BRS-OC-1 |

## Traceability

| Business ID | Stakeholder IDs |
|---|---|
| BRS-OC-1 | STRS-OC-1, STRS-OC-3, STRS-OC-6 |
| BRS-OC-2 | STRS-OC-4 |
| BRS-OC-3 | STRS-OC-2, STRS-OC-5 |
| BRS-OC-4 | Implementation dependency in @go.mod |
