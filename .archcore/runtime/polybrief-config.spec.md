---
title: "polybrief settings file and overrides"
status: draft
tags:
  - "spec"
  - "polybrief"
---

## Purpose & Scope

Normative for the settings of the Go binary `polybrief` (@config.go): where the settings file lives, its syntax, every key, the `-o` and `-w` overrides, and the order in which sources win. Dependents: people who edit the file, host agents that pass `-o`, and the binary's launcher and runner. Out of scope: command parameters other than `-o`, `-w` and `--config` (polybrief-cli spec) and the pattern format (polybrief-pattern-file spec).

## Surface

- File: `--config FILE`, else `$POLYBRIEF_CONFIG`, else `${XDG_CONFIG_HOME:-~/.config}/polybrief/polybrief.conf`.
- Syntax, one item per line: a `#` comment line, a blank line, a section header `[codex]`, `[claude]`, or `[opencode]`, or `key = value`. Lists are comma-separated. Values are literal after trimming; there are no quotes, and `#` after a value is part of the value. An empty value means the default.
- A key before the first section header is a general key, or a client key in dotted form (`codex.model`). A key under a section header is a client key of that section.
- Overrides: `-o KEY=VALUE`, repeatable, where `KEY` is a general key or `client.key`; `-w LIST` names the workers of a stage without `run:` lines and keeps only the listed clients in a stage with `run:` lines; it does not set `workers`.

Client keys, in `[codex]`, `[claude]`, or `[opencode]`:

| Key | Allowed values | Default |
|---|---|---|
| `model` | letters, digits and `. _ : / -`; opencode requires `provider/model` when set | codex: top-level `model` of `${CODEX_HOME:-~/.codex}/config.toml`; claude: the CLI default; opencode: none, required when opencode runs |
| `effort` | codex: `minimal low medium high xhigh`; claude: `low medium high xhigh max`; unavailable in `[opencode]` | codex: top-level `model_reasoning_effort` of `config.toml`; claude: the CLI default |
| `variant` | opencode only; letters, digits and `. _ : / -` | OpenCode CLI default |
| `web` | `on`, `off` | `off` |

General keys:

| Key | Allowed values | Default |
|---|---|---|
| `workers` | `codex`, `claude`, `opencode`; each at most once; read by direct `polybrief launch` calls only | `codex, claude` |
| `pattern` | a pattern name of `a-z`, `0-9`, `-` | `parallel` |
| `timeout` | whole seconds, at least 1 | `900` |
| `max_calls` | 1 to 40 | `12` |
| `env` | environment variable names | none |
| `context_dirs` | directories outside the reviewed tree; `~/` expands | none |
| `secret_names` | file name or path globs | none |
| `max_diff_bytes` | whole number, at least 1000 | `400000` |
| `history` | `on`, `off` | `on` |
| `tool_log` | `on`, `off` | `on` |
| `log` | a file path (`~/` expands) or `off` | `${XDG_STATE_HOME:-~/.local/state}/polybrief/polybrief-runs.tsv` |
| `patterns_dir` | a directory path | `$POLYBRIEF_PATTERNS_DIR`, else `${XDG_CONFIG_HOME:-~/.config}/polybrief/patterns` |

- Sources, as `polybrief config` prints them: `default`, `codex-config`, `environment`, `file:<line>`, `flag`.
- Retired settings-file key: `expect`. A one-run `-o expect=REGEX` override remains available for caller-owned challenge protocols; it does not alter the settings file.

## Normative Behavior

1. WHEN `--config` is set, the binary MUST read the settings from that file.
2. WHEN `--config` is unset and `POLYBRIEF_CONFIG` is set, the binary MUST read the settings from `POLYBRIEF_CONFIG`.
3. The binary MUST treat a key under `[codex]`, `[claude]`, or `[opencode]` and its dotted form as one setting.
4. WHEN a file sets one key twice, the binary MUST use the later line.
5. WHEN `-o` sets a key, the binary MUST use that value over the file and the default.
6. WHEN the file sets a key that `-o` does not, the binary MUST use the file value over the default.
7. WHILE `codex.model` or `codex.effort` is unset, the binary MUST take it from the top level of `config.toml`.
8. The binary MUST NOT take a Codex model or effort from a table of `config.toml`.
9. WHEN `-o` sets `max_calls`, the binary MUST use it over the pattern's `max-calls`.
10. WHEN a pattern sets `max-calls` and `-o` does not, the binary MUST use the pattern's value over the file.
11. The binary MUST validate every setting before it starts any worker.
12. WHEN the file sets `expect`, the binary MUST ignore it and print `polybrief: ignored setting expect` on stderr.
13. WHEN a run supplies `-o expect=REGEX`, the binary MUST apply that answer contract to its worker calls, after validating the expression.
14. WHEN the command is `config`, the binary MUST print every key of both tables with its value and source.
15. WHEN `[opencode]` sets `variant`, the binary MUST pass its value as OpenCode `--variant` through the launcher.

## Constraints & Invariants

- Constraint: the file holds names, never secret values: `env` lists variable names, and the values come from the caller's environment.
- Constraint: a pattern sets only its participants and `max-calls`; models, effort, web access, environment and timeout come from the settings.
- Invariant: an empty or absent default file gives a working run with the defaults above.
- Invariant: a file written for swarm 0.1.0 with dotted keys reads the same in the binary.

## Failure Behavior

Each failure below exits 2 before any worker starts and names the key and its source.

1. IF `--config` or `POLYBRIEF_CONFIG` names a file that does not exist, THEN the binary MUST refuse the run.
2. IF the default file does not exist, THEN the binary MUST use the defaults and print `CONFIG_FILE<TAB><path><TAB>absent`.
3. IF a line holds an unknown key or an unknown section, THEN the binary MUST refuse the file with `<file>:<line>`.
4. IF a line is not a comment, a header or `key = value`, THEN the binary MUST refuse the file with `<file>:<line>`.
5. IF a dotted key appears under a section header, THEN the binary MUST refuse the file with `<file>:<line>`.
6. IF a value is outside its allowed values, THEN the binary MUST refuse it and list the allowed values.
7. IF an `-o` argument has no `=`, THEN the binary MUST refuse the call.
8. IF the settings file lies inside the reviewed directory, THEN the binary MUST refuse the run.
9. IF a run includes an `opencode` worker and `opencode.model` is empty, THEN the binary MUST refuse the run before any worker starts.

## Conformance

An implementation is conformant when it satisfies behaviors 1–15, both invariants and failure rules 1–9. Full example files are in the polybrief reference doc.

```
Given [claude] effort = high in the file
When  polybrief config -o claude.effort=max runs
Then  it prints CONFIG<TAB>claude.effort<TAB>max<TAB>flag
```
