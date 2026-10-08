---
title: "Polybrief command and operation reference"
status: accepted
tags:
  - "polybrief"
---

## Overview

Reference for the argument-only Go binary `polybrief`. @README.md is the short start; @main.go, @config.go, @runner.go, and @launch.go implement the command, settings, orchestration, and worker profiles. The CLI, runtime-settings, pattern-file, and pattern-runner specs own the contracts. The argument-only decision is @.archcore/architecture/arguments-only-runtime.adr.md.

## Installation

@install.sh installs the binary in `~/.local/bin/polybrief` on macOS and Linux. @install.ps1 installs it in `%LOCALAPPDATA%\Programs\polybrief` on Windows and adds that directory to the user PATH. Both scripts verify the downloaded release archive against `checksums.txt`, accept `POLYBRIEF_VERSION` and `POLYBRIEF_INSTALL_DIR`, and install no configuration files. A manual install uses the archive matching the OS and architecture. Go users can run `go install github.com/ivklgn/polybrief@latest` with Go 1.25 or newer. Windows worker isolation is experimental.

## Inputs and outputs

- A run takes one caller-owned brief file, or `-` for stdin. `-b REF` adds Git context but does not choose a brief.
- `-p NAME` chooses an embedded pattern: `parallel` (default), `twice`, `crosscheck`, or `panel`.
- `-p FILE` reads a caller-owned Markdown pattern. `polybrief plan -p FILE` validates it without starting a worker.
- `-c FILE` adds a caller-owned checklist. A pattern names it by the file name without `.md`.
- `-w LIST` selects workers. `-o KEY=VALUE` changes a runtime setting for one command.
- No polybrief home or settings file is read. Install scripts place only the binary.
- Run output starts with `OUT<TAB>directory`, which holds `brief.md`, optional `change.json`, optional `agents/*.md`, prompts, answers, status, and launcher logs. It ends with `RESULT` when stage execution reaches a result. `complete` means all stages had acceptable answers; `partial` means stages had answers despite a failed participant; `stale` means the selected Git inputs changed; `failed` means the run produced no usable stage result.
- The default log is `${XDG_STATE_HOME:-~/.local/state}/polybrief/polybrief-runs.tsv`; `-o log=off` disables it.

## Exit codes and output lines

- Exit codes: 0 when every executed stage has an `ok` answer, including `partial`; 1 for `stale`, no stage answer, or the call limit; 2 for an input or infrastructure error; 143 when stopped by a signal.
- Run lines, tab-separated, in this order: `OUT`, `RUN`, `PLAN stage workers rounds`, `CALLS planned limit`, `STAGE`, `WORKER stage round name status secs path worker model`, `TOOLS`, `TOKENS`, `RESULT`.
- After `RESULT`, every answer is printed inline between `<answer-TAG stage round from status>` tags. `TAG` is random for each run.
- When a worker is `missing` (CLI not on PATH) or not `ok`, the launcher prints one hint line on stderr. It names the worker and, for a failure, the path of its `<name>.log`.
- `--label TEXT` sets the label of the run in the run log.
- `yield RUN NAME=RAISED/KEPT/ONLY` records counts the caller verified: findings raised, findings kept after verification, and findings found only by that worker. The run-log columns are in @.archcore/runtime/polybrief-review.spec.md.

## Commands

| Command | Effect |
|---|---|
| `polybrief -C repo brief.md` | Independent answers in `repo` with embedded `parallel` |
| `polybrief -C repo -b main brief.md` | Add the Git change from `main` to the working tree |
| `polybrief -p crosscheck brief.md` | Independent answers, then cross-check |
| `polybrief -p ./my-pattern.md brief.md` | Run a custom pattern file |
| `polybrief -w opencode -o opencode.model=openai/gpt-5 brief.md` | Run OpenCode alone |
| `polybrief -o timeout=1800 brief.md` | Change timeout for one run |
| `polybrief plan -p ./my-pattern.md` | Validate stages and show maximum calls |
| `polybrief patterns` | List built-in patterns |
| `polybrief config -o codex.effort=high` | Show effective settings and sources |
| `polybrief yield -o log=./runs.tsv R1 codex=3/2/1` | Record caller-verified counts |

## Brief and checklist

A brief is plain text. The copyable review and research briefs live at @examples/code-review/references/brief.md and @examples/research/references/brief.md. A checklist adds one named set of criteria to a worker prompt; it does not judge results. `panel` needs `review-security.md` and `review-tests.md`, supplied with `-c`; the files live in @examples/code-review/references/. Polybrief identifies a checklist by its basename, so moving it into `references/` does not change the lane name. Frontmatter is removed before a checklist reaches the worker. The caller checks evidence and makes final decisions.

The copyable @examples/code-review/SKILL.md calls `parallel` with Codex and
OpenCode, the Git merge base, and the required OpenCode model. The copyable
@examples/research/SKILL.md calls `crosscheck` with Claude and Codex and a
caller-owned brief. Both skills call the binary directly and include references
for reading worker output and verifying claims.

## Custom pattern from scratch

Save this file as `my-check.md`:

```markdown
---
name: my-check
description: Two independent answers.
workers: codex, claude
max-calls: 2
---

## answer

{{brief}}

Give your conclusion and cite supporting files.
```

Run `polybrief plan -p ./my-check.md`, then `polybrief -p ./my-check.md ./question.md`. A header names the pattern and default workers. Each `##` section is one stage. Stage settings, such as `- input: others`, go immediately after its heading. The stage prompt follows. `{{brief}}` inserts the task; `{{input}}` inserts prior answers when `input` is set. The pattern-file spec owns the full syntax.

## Runtime settings

`polybrief config` lists every key and its current value. Most settings use built-in defaults; Codex model and effort may come from the top level of `${CODEX_HOME:-~/.codex}/config.toml`. Use repeated `-o` arguments when you need changes for one command, for example `-o claude.web=on -o max_calls=8`. OpenCode needs `-o opencode.model=provider/model` when selected. The runtime-settings spec lists every key, allowed value, and default.

## Limits and checks

Workers run with read-only CLI permissions, not an OS filesystem sandbox. They can read files available to the OS account. Secret-name filtering affects generated Git diffs, not caller-supplied briefs or checklists. OpenCode's `read` tool denies `.env` files, but its `grep` can still find an unignored `.env`; managed OpenCode configuration can override the local profile. The caller supplies trusted brief, pattern, and checklist files and verifies every claim. A custom pattern inside the target directory is refused so the target change cannot rewrite its workflow. Each worker call spends CLI subscription limits or an API key.

`go test ./...`, `bash tests/test_review.sh`, `bash tests/test_pattern.sh`, and `bash tests/test_cli.sh` use fake workers and spend no model quota. `POLYBRIEF_TEST_REAL_OPENCODE=1 go test -run TestInstalledOpenCodeProfile ./...` checks an installed OpenCode profile without a model call. Historical measurements imported from ivklgn-kit do not validate a newer third-party release.
