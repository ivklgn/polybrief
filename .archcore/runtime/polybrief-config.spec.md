---
title: "Polybrief runtime settings and argument overrides"
status: accepted
tags:
  - "spec"
  - "polybrief"
---

## Purpose & Scope

Normative for effective runtime settings (@config.go): defaults, `-o` overrides, validation, and source reporting. The binary has no polybrief settings file or home. The decision is @.archcore/architecture/arguments-only-runtime.adr.md.

## Surface

- Public override: `-o KEY=VALUE`, repeatable for run, plan, config, and yield. The runner forwards it as internal `--set` to the launcher.
- Client selection: `-w LIST` chooses workers in the pattern; the internal launcher also accepts `--workers`. `-o workers=...` is refused.
- Sources shown by `polybrief config`: `default`, `codex-config`, or `flag`.
- Codex model and effort default to top-level `model` and `model_reasoning_effort` in `${CODEX_HOME:-~/.codex}/config.toml`; the parser stops at the first TOML table.

| Key | Allowed values | Default |
|---|---|---|
| `workers` | distinct `codex`, `claude`, `opencode` (internal launcher) | `codex,claude` |
| `timeout` | whole seconds, 1 to 86400 | `900` |
| `max_calls` | 1 to 40 | `12` |
| `env` | comma-separated environment variable names | empty |
| `context_dirs` | comma-separated directory paths | empty |
| `secret_names` | comma-separated file name or path globs; each is validated as a glob and matched case-insensitively | empty |
| `max_diff_bytes` | whole number, at least 1000 | `400000` |
| `history`, `tool_log` | `on` or `off` | `on` |
| `log` | file path or `off` | `${XDG_STATE_HOME:-~/.local/state}/polybrief/polybrief-runs.tsv` |
| `expect` | valid Go regexp (RE2) expression | empty |
| `codex.model` | letters, digits, `. _ : / -` | top-level Codex config |
| `codex.effort` | `minimal low medium high xhigh` | top-level Codex config |
| `claude.model` | letters, digits, `. _ : / -` | Claude CLI default |
| `claude.effort` | `low medium high xhigh max` | Claude CLI default |
| `codex.web`, `claude.web`, `opencode.web` | `on` or `off` | `off` |
| `opencode.model` | `provider/model`; required if OpenCode runs | empty |
| `opencode.variant` | letters, digits, `. _ : / -` | OpenCode CLI default |

## Normative Behavior

1. WHEN `-o` names a known key, the binary MUST use its value for that command.
2. WHEN `-o` repeats a key, the binary MUST use the last value.
3. WHEN no argument sets a key, the binary MUST use its built-in default.
4. WHEN Codex model or effort is unset, the binary MUST read only the top level of `config.toml` for that value.
5. WHEN `polybrief config` runs, the binary MUST print each effective key, value, and source.
6. WHEN a pattern sets `max-calls`, the runner MUST use it over the default `max_calls`.
7. WHEN `-o max_calls=N` is set, the runner MUST use it over the pattern limit.
8. WHEN `-o expect=REGEX` is set, the launcher MUST apply the validated answer contract.
9. WHEN OpenCode runs without `opencode.model`, the binary MUST refuse the run before starting a worker.

## Constraints & Invariants

- No polybrief settings file is read. `--home` and `--config` are unsupported.
- `env` names variables; their values come from the caller's environment.
- A pattern selects participants and call limit, not model, effort, web, environment, or timeout.

## Failure Behavior

1. IF an override lacks `=`, THEN the binary MUST refuse it.
1a. IF `-o` names `workers`, THEN the binary MUST direct the caller to `-w`.
2. IF an override names an unknown key, THEN the binary MUST name the key and refuse it.
3. IF a value is outside its allowed range, THEN the binary MUST name the key and refuse it before workers start.
4. IF a command uses `--home` or `--config`, THEN the binary MUST reject the flag.

## Conformance

`go test ./...` and the black-box checks in @tests/ cover defaults, overrides, validation, and worker selection.