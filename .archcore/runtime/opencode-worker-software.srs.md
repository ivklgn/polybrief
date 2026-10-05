---
title: "OpenCode worker software requirements"
status: draft
tags:
  - "security"
  - "polybrief"
---

## Scope

Specify the settings parser and launcher changes for OpenCode 1.18.34. The runner remains a consumer of the launcher's known-worker interface.

## Software Requirements

| ID | Component | Requirement | Parent |
|---|---|---|---|
| SRS-OC-1 | @config.go | The settings parser MUST recognize `opencode` and its model, variant, and web keys. | SYRS-OC-1 |
| SRS-OC-2 | @launch.go | WHEN selected, the launcher MUST pass the prepared prompt through OpenCode stdin. | SYRS-OC-1 |
| SRS-OC-3 | @launch.go | WHILE starting OpenCode, the launcher MUST use clean HOME and XDG directories. | SYRS-OC-2 |
| SRS-OC-4 | @launch.go | WHILE starting OpenCode, the launcher MUST disable project configuration and external plugins. | SYRS-OC-3 |
| SRS-OC-5 | @launch.go | WHILE starting OpenCode, the launcher MUST apply a deny-by-default tool profile. | SYRS-OC-4 |
| SRS-OC-6 | @launch.go | WHEN JSON text events finish, the launcher MUST write the text of the last message to the answer artifact. | SYRS-OC-5 |
| SRS-OC-7 | @launch.go | WHEN JSON usage exists, the launcher MUST include cache input and reasoning output in token totals. | SYRS-OC-5 |
| SRS-OC-8 | @launch.go | WHEN context directories exist, the launcher MUST add read access only for those paths. | SYRS-OC-6 |
| SRS-OC-9 | @launch.go | WHEN user credentials exist, the launcher MUST make them readable in isolated OpenCode data storage. | SYRS-OC-9 |
| SRS-OC-13 | @patterns/opencode.md | The built-in OpenCode pattern MUST name OpenCode as its sole worker. | SYRS-OC-7 |
| SRS-OC-14 | @launch.go | WHEN a model or variant is set, the launcher MUST pass it through `--model` or `--variant`. | SYRS-OC-8 |
| SRS-OC-15 | @launch.go | WHEN the worker finishes or the launcher is stopped, the launcher MUST remove the private HOME and XDG directories. | SYRS-OC-10 |
| SRS-OC-16 | @launch.go | WHEN `env` names `OPENCODE_API_KEY`, `OPENCODE_ENABLE_EXA`, or `OPENCODE_ENABLE_PARALLEL`, the launcher MUST pass it. | SYRS-OC-2 |
| SRS-OC-17 | @launch.go | WHEN `env` names any other `OPENCODE_` or `XDG_` variable, the launcher MUST withhold it and name it on stderr. | SYRS-OC-2 |
| SRS-OC-18 | @launch.go | WHILE OpenCode runs, the launcher MUST request `--print-logs --log-level WARN` and keep that stderr in the worker log. | SYRS-OC-11 |
| SRS-OC-19 | @launch.go, @runner.go | WHEN OpenCode is selected without `opencode.model`, the launcher and the runner MUST refuse the run before any worker starts. | SYRS-OC-8 |
| SRS-OC-20 | @launch.go | WHEN the last step has no text or ended with `length`, `tool-calls`, or `unknown`, the launcher MUST report `failed`. | SYRS-OC-5 |

## External Interfaces

- OpenCode 1.18.34 CLI options: `run`, `--pure`, `--format json`, `--agent`, `--dir`, `--model`, `--variant`, `--print-logs`, `--log-level`.
- OpenCode environment: `OPENCODE_DISABLE_PROJECT_CONFIG`, `OPENCODE_DISABLE_CLAUDE_CODE`, `OPENCODE_DISABLE_AUTOUPDATE`, `OPENCODE_DISABLE_LSP_DOWNLOAD`, `OPENCODE_CONFIG_CONTENT`, and HOME/XDG directory variables. Built-in plugins stay enabled. Caller variables `OPENCODE_API_KEY`, `OPENCODE_ENABLE_EXA`, and `OPENCODE_ENABLE_PARALLEL` pass when named.
- OpenCode JSON events: `text`, `tool_use`, `step_finish`, `error`.

## Non-Functional Requirements

| ID | Requirement | Parent |
|---|---|---|
| SRS-OC-10 | The launcher MUST keep credentials out of retained OUT artifacts. | SYRS-OC-9 |
| SRS-OC-11 | The launcher MUST leave the reviewed directory unchanged during its own setup and cleanup. | SYRS-OC-10 |
| SRS-OC-12 | The implementation MUST add no Go module dependency. | BRS-OC-4 |

## Verification Matrix

| IDs | Check |
|---|---|
| SRS-OC-1 | `polybrief config` and invalid-setting cases |
| SRS-OC-2 through SRS-OC-5, SRS-OC-8 through SRS-OC-11, SRS-OC-14 through SRS-OC-18 | fake OpenCode worker and local isolation probe |
| SRS-OC-6, SRS-OC-7, SRS-OC-20 | JSON fixture assertions |
| SRS-OC-12 | `go.mod` and `go test ./...` |
| SRS-OC-13, SRS-OC-19 | `bash tests/test_cli.sh` |
