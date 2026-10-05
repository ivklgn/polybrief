---
title: "OpenCode worker system requirements"
status: draft
tags:
  - "security"
  - "polybrief"
---

## System Purpose and Scope

Polybrief parses settings in @config.go, prepares the prompt and starts workers in @launch.go, and exposes the known worker set to the runner in @runner.go. The external OpenCode process and its provider are outside Polybrief.

## Operational Modes

- Configuration inspection prints OpenCode settings and the known worker list without a model call.
- A launch starts OpenCode only when selected.
- The runner names OpenCode through the launcher; it does not construct OpenCode arguments.

## System Requirements

| ID | Requirement | Parent |
|---|---|---|
| SYRS-OC-1 | WHEN selected, the launcher MUST invoke OpenCode noninteractively with JSON events. | STRS-OC-1, STRS-OC-2 |
| SYRS-OC-2 | WHILE launching OpenCode, the launcher MUST omit caller variables not named for pass-through, and named variables that would change the OpenCode profile. | STRS-OC-4 |
| SYRS-OC-3 | WHILE launching OpenCode, the launcher MUST exclude project rules and external plugins. | STRS-OC-4 |
| SYRS-OC-4 | WHILE launching OpenCode, the launcher MUST deny write and shell tools. | STRS-OC-4 |
| SYRS-OC-5 | WHEN OpenCode emits events, the launcher MUST extract answer text, tool calls, and usage. | STRS-OC-2 |
| SYRS-OC-6 | WHEN a context directory is configured, the launcher MUST allow OpenCode to read that directory. | STRS-OC-1 |
| SYRS-OC-7 | WHEN the caller selects the built-in OpenCode pattern, the runner MUST start one OpenCode participant. | STRS-OC-1 |
| SYRS-OC-8 | WHEN an operator sets a model or variant, the launcher MUST pass it to OpenCode. | STRS-OC-3 |
| SYRS-OC-9 | WHEN a stored OpenCode login exists, the launcher MUST make it usable to the worker and keep its bytes out of retained artifacts. | STRS-OC-6 |
| SYRS-OC-10 | WHILE launching OpenCode, the launcher MUST keep its private directories outside the reviewed tree. | STRS-OC-4 |
| SYRS-OC-11 | WHEN OpenCode reports warnings or errors, the launcher MUST keep them in the worker log. | STRS-OC-2 |

## System Interfaces

- CLI: `opencode run` with a piped prompt and `--format json`.
- Configuration: `opencode.model`, `opencode.variant`, and `opencode.web`.
- Output: existing `WORKER`, `TOOLS`, and `TOKENS` rows.

## Verification Approach

- Fake-worker shell checks assert command arguments, environment, and event parsing.
- An isolated local OpenCode 1.18.34 configuration probe checks effective permissions and absence of project additions.
- A model-backed smoke run remains a separate check because fake workers spend no quota.

## Traceability

| Stakeholder ID | System IDs |
|---|---|
| STRS-OC-1 | SYRS-OC-1, SYRS-OC-6, SYRS-OC-7 |
| STRS-OC-2 | SYRS-OC-1, SYRS-OC-5, SYRS-OC-11 |
| STRS-OC-3 | SYRS-OC-8 |
| STRS-OC-4 | SYRS-OC-2, SYRS-OC-3, SYRS-OC-4, SYRS-OC-10 |
| STRS-OC-5 | Existing launcher missing-worker path |
| STRS-OC-6 | SYRS-OC-9 |
