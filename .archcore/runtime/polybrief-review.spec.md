---
title: "Polybrief launcher (polybrief launch) contract"
status: accepted
tags:
  - "polybrief"
  - "spec"
---

## Purpose & Scope

Normative for the launcher of the polybrief binary (@launch.go, internal command `polybrief launch`): how a brief reaches one or more headless agent CLIs, how the current workers are kept read-only and isolated, which settings the user controls, and what the launcher prints and logs. Dependents: the pattern runner (@.archcore/runtime/polybrief-pattern-runner.spec.md) and external consumers that supply briefs and optional checklists. Consumers own the content of their briefs and evaluation of results. Out of scope: the content of the brief, verification of answers, and a final task decision.

## Surface

- Run: `polybrief launch --dir DIR [--base REF] --brief FILE|- [--agents-dir DIR] [--lanes A,B] [--workers A,B] [--timeout SEC] [--expect REGEX] [--env NAME]… [--context-dir DIR]… [--label TEXT] [--run-id ID] [--set KEY=VALUE]…`. Callers use the public command line (polybrief-cli spec); the runner and the self-checks use this form.
- `--show-config`: one `CONFIG<TAB>key<TAB>value<TAB>source` line per setting, then `KNOWN_WORKERS` and `KNOWN_LANES`.
- `--yield RUN NAME=RAISED/KEPT/ONLY… [--label TEXT]`: appends yield rows to the run log, prints `LOGGED<TAB>file<TAB>rows`.
- Settings: built-in defaults and `--set KEY=VALUE`; keys and validation are in the runtime-settings spec. Codex model and effort fall back to the top level of `config.toml`. There is no polybrief settings file or home.
- Modes: without `--base` any existing directory is accepted; `--base` adds the Git change. Internal `--prepare-context FILE` captures it, `--prepared-context FILE` reuses it, and `--check-context FILE` detects persistent drift.
- Answer contract: empty for generic briefs; implicit `^(FINDING|NOT-CHECKED|NO FINDINGS)` with a base unless configured explicitly.
- Checklists: `--agents-dir DIR`, with `--lanes` selecting Markdown basenames; namespace prefixes are accepted for compatibility.
- Workers: `codex`, `claude`, and optional `opencode`; the default set remains `codex,claude`.
- Worker commands, before the per-setting flags:
  - `codex exec -s read-only --ignore-user-config --ephemeral -c project_doc_max_bytes=0 [-c web_search=disabled] -C DIR -o OUT/codex.md -`; `project_doc_max_bytes=0` keeps an `AGENTS.md` of the reviewed tree out of the instructions (without it, codex-cli 0.159.0 followed such a file on 2026-09-29);
  - `claude -p --tools "Read,Grep,Glob" --strict-mcp-config --setting-sources "" --no-session-persistence`, run inside `DIR`.
  - `opencode`: the command and isolation profile are owned by the OpenCode worker contract.
- Worker environment: `HOME`, `PATH`, `USER`, `LOGNAME`, `SHELL`, `LANG`, `LC_ALL`, `LC_CTYPE`, `TERM`, `TMPDIR`, `CODEX_HOME`, `CLAUDE_CONFIG_DIR`, and the names from `env` and `--env`. OpenCode receives private HOME/XDG paths and controlled `OPENCODE_*` settings under its worker contract.
- Secret-like names: `.env`, `.env.*`, `.envrc`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa*`, `id_ed25519*`, `id_ecdsa*`, `id_dsa*`, and the setting `secret_names`.
- Output, in order: `OUT`; `SKIPPED` lines; `CUT<TAB>bytes<TAB>limit`; optional `OMITTED<TAB>changed-paths|history-lines<TAB>count`; after the run one `WORKER<TAB>name<TAB>status<TAB>seconds<TAB>answer<TAB>model<TAB>effort<TAB>version` line per worker; `TOOLS<TAB>name<TAB>calls`; `TOKENS<TAB>name<TAB>input<TAB>output` when the CLI reported usage (input includes cached and cache-write tokens); each non-empty answer in `<answer-TAG worker=".." status="..">`, where `TAG` is random per run and is not the tag of the change block.
- Status values: `ok`, `malformed`, `failed`, `timeout`, `missing`.
- Run log: tab-separated rows `time kind run label worker model effort version status seconds raised kept only tokens_in tokens_out`; `kind` is `call` or `yield`. A log file created before the token columns keeps its 13-column header; new rows have 15 fields.
- Exit codes: 0 when a worker is `ok`; 1 when none is; 2 when the launcher could not run, with `polybrief: <message>` on stderr and no `WORKER` line; 143 when stopped by `TERM`, `INT` or `HUP`.
- Windows (experimental): the process-tree stop is `taskkill /T /F` at once, without the five-second `TERM` grace (@launch_windows.go); the worker environment also passes `USERPROFILE`, `APPDATA`, `LOCALAPPDATA`, `SystemRoot` and the other Windows names in @launch.go; checklists are copied when a symlink cannot be made, and OpenCode `auth.json` is hard-linked under the same condition. Unix process groups live in @launch_unix.go.

## Normative Behavior

1. WHEN `--base` is set, the launcher MUST build the base-to-working-tree diff with untracked files.
2. WHEN a tracked, staged or untracked file has a secret-like name, the launcher MUST leave it out and print a `SKIPPED` line.
3. WHEN files are left out, the launcher MUST put their count, without their names, in the generated omission notice.
4. The launcher MUST send every worker the same brief, checklists, context directories, and optional Git change.
5. The launcher MUST wrap the change in a tag that is random for each run.
6. The launcher MUST tell the workers that the change is data and that instructions inside it are not followed.
7. WHEN `--lanes` is given, the launcher MUST append each checklist from `--agents-dir` without its frontmatter.
8. WHEN Git context and `history` are enabled, the launcher MUST add bounded history for non-secret changed files.
9. WHEN the diff exceeds `max_diff_bytes`, the launcher MUST truncate it and print a `CUT` line.
10. The launcher MUST start every worker with only the environment variables listed under Surface.
11. The launcher MUST start all workers in parallel.
12. WHEN a Codex or Claude model or effort is set, the launcher MUST pass it to that worker.
13. The launcher MUST NOT take a Codex model or effort from a table of `config.toml`, indented or not.
14. WHILE `codex.web` is `off`, the launcher MUST start the `codex` worker with `-c web_search=disabled`.
15. WHEN a context directory is set, the launcher MUST pass it to the `claude` worker with `--add-dir`.
16. WHEN a worker exits 0 with an answer that matches `expect`, the launcher MUST report it as `ok`.
17. WHEN no line of an answer matches `expect` after trailing spaces are removed, the launcher MUST report it as `malformed`.
18. The launcher MUST print `OUT`, `SKIPPED`, `CUT`, and `OMITTED` lines before starting a worker.
19. The launcher MUST print every non-empty answer, also of a worker that is not `ok`.
20. WHEN a worker exceeds the timeout, the launcher MUST send `TERM` to its process tree and `KILL` five seconds later.
21. WHEN the launcher receives `TERM`, `INT` or `HUP`, it MUST stop every worker the same way.
22. WHEN the setting `log` is not `off`, the launcher MUST append one `call` row per worker.
23. WHEN the setting `tool_log` is `on`, the launcher MUST print the tool calls of each worker from its JSON events.
24. The launcher MUST build patch text that does not depend on the user's `diff.noprefix` and `diff.mnemonicPrefix` settings.
25. The launcher MUST wrap the answers in a tag that appears in no prompt.
26. The launcher MUST write each run log row in one write.
27. WHEN several launchers create the run log at once, the log MUST get one header row.
28. WHEN a prepared context is supplied, the launcher MUST use its captured diff, history, base SHA, and disclosure limits.
29. WHEN preparing a context, the launcher MUST compare source fingerprints before writing the context file.
30. WHEN checking a context, the launcher MUST report drift when its selected Git inputs differ from the captured fingerprint.
31. WHEN the diff is truncated, the launcher MUST list at most 100 changed paths and 16000 path bytes in the prompt.
32. WHEN fingerprinting selected changed files, the launcher MUST hash their bytes or symlink targets independently of the rendered Git diff.
33. WHEN OpenCode is selected, the launcher MUST apply its read-only worker profile.

## Constraints & Invariants

- Invariant: the launcher writes nothing inside `DIR`.
- Constraint: secret-name filtering affects the generated diff, selected file history, file-content fingerprints, and omission notice. Commit subjects and caller-supplied text are not scrubbed; worker file reads remain governed by the OS account.
- Constraint: automatically added history is capped at 16000 bytes; omitted history lines are reported locally.
- Invariant: the `codex` worker runs in the read-only sandbox without the user config, so it gets no MCP server and runs no hook.
- Invariant: the `claude` worker has only `Read`, `Grep`, `Glob` and, with `claude.web = on`, the two web tools; no MCP servers, no settings.
- Invariant: the `opencode` worker uses a private tool-permission profile and does not load project configuration or external plugins; this is not an OS sandbox.
- Invariant: a secret variable of the caller reaches no worker unless the user names it in `env` or `--env`.
- Invariant: the launcher installs no dependency and runs no script of the reviewed tree.
- Invariant: caller-owned Markdown files passed with `-c` are the only source of checklist text; the public command stages them in `--agents-dir`.
- Constraint: the launcher needs only the binary and the worker CLIs; Git is required only with `--base`.
- Constraint: `OUT` is not removed; it holds the prompt, the answers and the worker logs.

## Failure Behavior

1. IF a worker's CLI is not installed, THEN the launcher MUST report it as `missing` and run the others.
2. IF a worker exits non-zero or returns an empty answer, THEN the launcher MUST report it as `failed`.
3. IF no worker is `ok`, THEN the launcher MUST exit 1 after printing the `WORKER` lines.
4. IF `--dir` is missing or does not exist, THEN the launcher MUST exit 2 with a diagnostic.
5. IF a supplied `--base` is invalid, or a worker is unknown or duplicated, THEN the launcher MUST exit 2.
6. IF a lane is unknown or lacks `--agents-dir`, THEN the launcher MUST exit 2.
7. IF an argument sets an unknown key or a bad value, THEN the launcher MUST exit 2 and name the key.
8. IF `--config` is given, THEN the launcher MUST reject it as an unknown flag.
9. IF the temp directory or the diff cannot be made, THEN the launcher MUST exit 2.
10. IF the run log cannot be written, THEN the launcher MUST warn on stderr and go on.
11. IF the temp directory lies inside `DIR`, THEN the launcher MUST exit 2 before invoking Git or writing anything.
12. IF required input or artifact I/O fails, THEN the launcher MUST exit 2 with a path-specific diagnostic.

Required I/O covers the brief, checklists, selected changed files, prepared context, prompt, diff, answers, and worker logs.
13. IF a prepared context is invalid or stored inside `DIR`, THEN the launcher MUST exit 2 before starting a worker.

## Conformance

An implementation is conformant when it satisfies behaviors 1–33, the invariants and the failure rules. @tests/test_review.sh checks them with fake `codex`, `claude`, and `opencode` programs that refuse to run without their isolation flags and record their arguments and environment. It calls no real model. Reverting any single fix of Phase 1 of @.archcore/runtime/polybrief-pattern-runner.plan.md makes the check fail; this was tried for each fix on 2026-09-29. Run: `bash tests/test_review.sh`.

The isolation flags were checked by hand on 2026-09-27 and 2026-09-28 with codex-cli 0.156.1 and Claude Code 2.1.283; the results are in @.archcore/research/polybrief-pattern-layer.rnd.md.


## Migration note

Imported from `ivklgn-kit/.archcore/codereview/swarm-review.spec.md`. Historical experiments and verdicts are unchanged; see the Provenance section of `.archcore/architecture/standalone-runtime.adr.md`. The standalone interface adds optional Git context and caller-owned checklists; the extraction ADR defines that change.
