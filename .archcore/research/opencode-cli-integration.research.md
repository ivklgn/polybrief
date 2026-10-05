---
title: "OpenCode 1.18.34 CLI integration for read-only workers"
status: draft
tags:
  - "research"
  - "polybrief"
---

## Goal

Establish the OpenCode 1.18.34 CLI contract needed for a read-only Swarm worker.

## Scope

Covered: noninteractive invocation, configuration precedence, project instructions, permissions, authentication, JSON events, and model selection. Method: official documentation, source at tag v1.18.34, installed CLI help, and isolated local configuration probes. Excluded: model quality, provider billing, managed organizational configuration, and OS-level write confinement.

## Coverage

- CLI invocation and event output: covered by CLI help and versioned source.
- Configuration and instructions: covered by versioned source and local probes.
- Tool permissions: covered by official permission documentation and a local config probe.
- Credential and data location: covered by official CLI documentation and versioned auth source.
- End-to-end provider answer: open gap.

## Sources

- OpenCode CLI, https://opencode.ai/docs/cli/ (accessed 2026-10-03).
- OpenCode permissions, https://opencode.ai/docs/permissions/ (accessed 2026-10-03).
- OpenCode configuration, https://opencode.ai/docs/config/ (accessed 2026-10-03).
- OpenCode v1.18.34 run source, https://github.com/anomalyco/opencode/blob/v1.18.34/packages/opencode/src/cli/cmd/run.ts (accessed 2026-10-03).
- OpenCode v1.18.34 configuration source, https://github.com/anomalyco/opencode/blob/v1.18.34/packages/opencode/src/config/config.ts (accessed 2026-10-03).
- OpenCode v1.18.34 instruction source, https://github.com/anomalyco/opencode/blob/v1.18.34/packages/opencode/src/session/instruction.ts (accessed 2026-10-03).
- OpenCode v1.18.34 auth source, https://github.com/anomalyco/opencode/blob/v1.18.34/packages/opencode/src/auth/index.ts (accessed 2026-10-03).
- OpenCode v1.18.34 file writes, https://github.com/anomalyco/opencode/blob/v1.18.34/packages/core/src/fs-util.ts (accessed 2026-10-03).
- OpenCode v1.18.34 plugins and flags, https://github.com/anomalyco/opencode/blob/v1.18.34/packages/opencode/src/plugin/index.ts, .../src/plugin/openai/codex.ts, .../src/effect/runtime-flags.ts (accessed 2026-10-03).
- OpenCode v1.18.34 usage, LSP and tools, https://github.com/anomalyco/opencode/blob/v1.18.34/packages/opencode/src/session/session.ts, .../src/lsp/lsp.ts, .../src/tool/read.ts, .../src/tool/registry.ts (accessed 2026-10-03).
- OpenCode v1.18.34 step loop, search and default model, https://github.com/anomalyco/opencode/blob/v1.18.34/packages/opencode/src/session/prompt.ts, .../src/session/processor.ts, .../src/provider/provider.ts, .../packages/core/src/ripgrep.ts (accessed 2026-10-03).

## Findings

- Installed `opencode --version` returned `1.18.34` on 2026-10-03. `opencode run --help` exposed `--pure`, `--format json`, `--model`, `--agent`, `--dir`, `--variant`, and the global `--print-logs` and `--log-level` options.
- `run.ts` reads piped stdin as the message and emits completed `text`, `tool_use`, `step_finish`, and `error` records in JSON mode.
- Documentation states that most permissions default to allow. An explicit catch-all deny with named read/search allows is needed for this worker.
- Configuration sources merge. `OPENCODE_CONFIG_CONTENT` alone cannot remove user or project additions. At v1.18.34, `OPENCODE_DISABLE_PROJECT_CONFIG=1` skips project configuration and project instruction files; `--pure` skips external plugins.
- The CLI documentation locates credentials at `~/.local/share/opencode/auth.json`. Versioned auth source reads from `Global.Path.data/auth.json`. An isolated data directory therefore needs a credential bridge or explicit provider environment variable.
- An isolated `opencode --pure debug config` probe showed no MCP entries, no external plugins, deny-by-default permissions, and no project canary agent. A `run --pure --format json` probe with an invalid model emitted a JSON error and did not execute a project plugin; it did not use model quota.
- The final Swarm launcher produced `WORKER opencode failed` from an invalid-model JSON error and left the target directory empty. A short model-backed attempt returned provider HTTP 401 for `openai/gpt-5-nano`; the listed OpenCode free model returned HTTP 403. Neither produced a model answer.
- `OPENCODE_DISABLE_DEFAULT_PLUGINS=1` skips OpenCode's internal plugins. They hold the OAuth loaders for OpenAI (ChatGPT), GitHub Copilot, GitLab, xAI, and other providers, so a linked OAuth login needs them; `--pure` alone skips only external plugins. The final launcher no longer sets this flag. The 401 run above had it set; whether that run used an OAuth login is not recorded.
- `Auth.set` writes `auth.json` with an in-place write and `chmod`, both of which follow a link. A token refresh therefore updates the user's file and is not lost on cleanup.
- Each turn of the session step loop creates a new assistant message with its own ID, and every part carries its `messageID`; the text of the last message is therefore the final answer, and earlier messages narrate tool calls.
- The step loop ends only when the last step finished with a reason other than `tool-calls` or `unknown` and made no tool call. Every `step_finish` part carries the step's `messageID` and its finish `reason`, so the last step shows whether the run ended with an answer, was cut off (`length`), or stopped unfinished.
- Without a configured model, OpenCode picks the first recent model from its state directory, else the best-ranked model of the first available provider. In the isolated profile the state directory is empty, so the choice depends on which credentials are present, not on the user's own OpenCode settings.
- The grep tool runs ripgrep with `--hidden`, so it searches dot files such as `.env` unless they are gitignored; the `read` permission rules do not apply to it.
- `step_finish` tokens report `input` without cache reads and writes, and `output` without reasoning tokens, so the launcher adds cache and reasoning back for its totals.
- A plain `read: allow` rule overrides OpenCode's default `*.env` ask rule. An `opencode debug agent` probe of the final profile resolves reads of `.env` and `.env.local` to deny and of `.env.example` and source files to allow.
- LSP servers start only when the configuration has an `lsp` key; the isolated profile has none, so the read tool starts no language server.
- `OPENCODE_DISABLE_PROJECT_CONFIG=1` also skips project `AGENTS.md` and `CLAUDE.md` files.
- The websearch tool exists only for the `opencode` providers, or when `OPENCODE_ENABLE_EXA` or `OPENCODE_ENABLE_PARALLEL` is set.
- Managed configuration has higher precedence than inline configuration in the current documentation. The OpenCode permission layer does not establish an OS filesystem sandbox.

## Synthesis

Implement the worker with clean HOME and XDG directories, disabled project configuration, `--pure`, a named deny-by-default agent, and JSON event parsing. Treat read-only as a CLI tool-permission boundary, and verify the reviewed tree stays unchanged in fake-worker and local probes.

## Open Gaps

- A successful provider response has not been obtained under the final Swarm launcher; the attempted OpenAI key received HTTP 401 and the tested free model received HTTP 403.
- The isolated profile has not been tested against managed organizational configuration.
- The listed findings validate OpenCode 1.18.34; a future major version needs a new compatibility check.
