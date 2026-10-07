---
title: "OpenCode read-only worker contract"
status: draft
tags:
  - "spec"
  - "polybrief"
---

## Purpose & Scope

Normative for OpenCode as one optional read-only Polybrief worker (@launch.go, @config.go). Callers, pattern authors, and the pattern runner depend on its worker name, settings, output, and isolation behavior. The contract covers OpenCode 1.18.34; it does not define provider quality or OS confinement.

## Surface

- Worker name: `opencode` in `workers`, `--workers`, `-w`, and pattern participants; `-w opencode` runs OpenCode alone in `parallel`.
- Settings: `opencode.model` (provider/model, required when OpenCode runs), `opencode.variant` (provider-specific), `opencode.web` (`on|off`, default `off`).
- Command: `opencode run --pure --format json --agent polybrief-readonly --dir DIR --print-logs --log-level WARN`, with optional model and variant.
- Result: existing `WORKER`, `TOOLS`, `TOKENS`, answer artifact, and run-log fields. The effort field holds the OpenCode variant.
- Source owners: @config.go, @launch.go, @runner.go; example settings in @polybrief.conf.example.

## Normative Behavior

1. WHEN a caller selects `opencode`, the settings parser MUST accept its name and settings.
2. WHILE defaults apply, the settings parser MUST keep `codex,claude` as the worker list.
3. WHEN a model is set, the launcher MUST pass it through `--model`.
4. WHEN a variant is set, the launcher MUST pass it through `--variant`.
5. WHEN starting OpenCode, the launcher MUST send its prepared prompt through stdin.
6. WHEN starting OpenCode, the launcher MUST request JSON events and select the named read-only agent.
7. WHILE starting OpenCode, the launcher MUST disable project configuration and external plugins.
8. WHILE starting OpenCode, the launcher MUST use private HOME and XDG directories outside the reviewed tree.
9. WHILE starting OpenCode, the launcher MUST deny all tool permissions except read, glob, grep, and list, and MUST deny reads of `*.env` and `*.env.*` files other than `*.env.example`.
10. WHILE `opencode.web=on`, the launcher MUST also allow webfetch and websearch.
11. WHILE `opencode.web=off`, the launcher MUST deny webfetch and websearch.
12. WHEN context directories are supplied, the launcher MUST allow reads under those directories.
13. WHEN user OpenCode credentials exist, the launcher MUST expose them inside the private data directory without copying their bytes to OUT.
14. WHEN OpenCode emits completed text events, the launcher MUST write the text of the last step's message to its answer artifact; earlier messages narrate tool calls.
15. WHEN `tool_log=on`, the launcher MUST count OpenCode tool events and usage events.
16. WHEN OpenCode reports usage, the launcher MUST include cached input and reasoning output in token totals.
17. WHEN `tool_log=off`, the launcher MUST still extract an answer from JSON events.
18. WHEN the worker finishes or the launcher is stopped, the launcher MUST remove its private HOME and XDG directories.
19. WHEN the caller runs `-w opencode` with a pattern whose stages have no `run:` lines, the runner MUST start one OpenCode participant per stage.
20. WHEN `env` or `--env` names `OPENCODE_API_KEY`, `OPENCODE_ENABLE_EXA`, or `OPENCODE_ENABLE_PARALLEL`, the launcher MUST pass it to OpenCode.
21. WHEN `env` or `--env` names any other `OPENCODE_` or `XDG_` variable, the launcher MUST withhold it from OpenCode and name it on stderr.
22. WHILE OpenCode runs, the launcher MUST send OpenCode's own warnings and errors to the worker log.

## Constraints & Invariants

- Invariant: @runner.go obtains the known worker set from the launcher and starts workers only through it.
- Invariant: the launcher writes no file inside the reviewed directory.
- Invariant: no caller environment variable reaches OpenCode unless included in the launcher allowlist or explicitly named with `env` or `--env`.
- Constraint: OpenCode permissions restrict its tools; they do not form an OS sandbox. Managed configuration can override inline configuration.
- Constraint: OpenCode's built-in plugins stay enabled; they hold the OAuth loaders of stored logins. OpenCode refreshes an OAuth token by rewriting `auth.json` in place, so the refresh reaches the user's file through the link.
- Constraint: the `.env` rule binds the read tool; OpenCode's grep searches hidden files, so it still finds text in a `.env` file that is not gitignored. Polybrief's secret-name filtering covers generated diffs only.
- Constraint: the stderr note of behavior 21 reaches the caller of a direct launcher call; the pattern runner shows launcher stderr only when the launcher exits 2.
- Constraint: OpenCode offers websearch only for its `opencode` providers or when `OPENCODE_ENABLE_EXA` or `OPENCODE_ENABLE_PARALLEL` is set; `opencode.web=on` permits it, it does not enable it.
- Constraint: the launcher records the OpenCode version in `WORKER` and the run log but does not compare it; the opt-in installed-profile test is the re-check after an update.
- Constraint: the profile targets OpenCode 1.18.34 behavior documented at https://opencode.ai/docs/cli/ and https://opencode.ai/docs/permissions/.

## Failure Behavior

1. IF the OpenCode CLI is absent, THEN the launcher MUST report `missing` and continue other workers.
2. IF OpenCode exits nonzero, THEN the launcher MUST report `failed`.
3. IF JSON events contain no answer, THEN the launcher MUST report `failed`.
4. IF JSON events contain an error, THEN the launcher MUST report `failed`.
5. IF OpenCode exceeds the timeout, THEN the launcher MUST terminate its process tree and report `timeout`.
6. IF private directory setup fails, THEN the launcher MUST exit 2 before starting any worker.
7. IF OpenCode is selected and `opencode.model` is empty, THEN the launcher and the runner MUST exit 2 before any worker starts. Without a model OpenCode picks one from the providers it finds, and the run could not name the model that answered.
8. IF the last step's message has no text, THEN the launcher MUST report `failed` instead of using earlier text.
9. IF the last step ended with `length`, `tool-calls`, or `unknown`, THEN the launcher MUST report `failed`; the answer was cut off or the step did not finish.

## Conformance

The implementation conforms when all behavior and failure clauses hold and the reviewed tree stays unchanged. Fake-worker checks cover arguments, the prompt on stdin, environment, web permissions, answer extraction, errors, an empty answer, setup failure, cleanup after a stop, a missing CLI, tool counts, and token totals. An installed OpenCode 1.18.34 configuration probe checks the effective local profile without a model call.
