---
title: "Isolate the OpenCode read-only worker profile"
status: accepted
tags:
  - "architecture"
  - "polybrief"
---

## Context

The existing launcher starts local CLIs with a narrow environment and a read-only worker profile (@launch.go). OpenCode merges user, project, inline, and managed configuration; user or project plugins and MCP entries can therefore affect an ordinary `opencode run`. Provider credentials live under the OpenCode data directory, so moving every XDG path without a credential bridge would lose an existing login.

## Decision

Use OpenCode 1.18.34 `run --pure` with temporary HOME and XDG directories, project configuration disabled, a deny-by-default inline agent, and a link to the user's existing `auth.json` in isolated data storage. OpenCode's built-in plugins stay enabled, because they hold the OAuth loaders that make a stored login work; `--pure` already skips external plugins.

The worker ships with a built-in one-worker pattern `opencode` and an `[opencode]` settings section. This extends the built-in pattern set and the client sections fixed in @.archcore/architecture/go-runtime.adr.md; OpenCode is not added to `parallel` or the default `workers`, because no real provider answer has been recorded yet.

Changed 2026-10-07: the built-in `opencode` pattern was removed; `-w opencode` selects OpenCode in `parallel` and `crosscheck`. OpenCode is still not in the default `workers`.

## Alternatives Considered

1. Inherit the user's OpenCode configuration — rejected because merged plugins, MCP entries, and project instructions would enter a Polybrief worker.
2. Use temporary directories without a credential bridge — rejected because an existing `opencode auth login` would become unavailable to the worker.
3. Allow shell commands through OpenCode permissions — rejected because a command allowlist cannot establish a read-only boundary for arbitrary command arguments.
4. Disable OpenCode's built-in plugins as well (`OPENCODE_DISABLE_DEFAULT_PLUGINS`) — rejected because they carry the OAuth loaders for OpenAI (ChatGPT), GitHub Copilot, GitLab, xAI, and other providers, so a stored OAuth login would stop working. Their tools stay denied by the permission profile.

## Consequences

- [expected] Existing OpenCode logins remain usable while worker sessions and caches stay in temporary directories.
- [expected] The worker can use read, glob, grep, and list; it cannot invoke OpenCode edit or shell tools through its permission profile.
- [expected] A process crash may leave a temporary directory; it contains a link to credentials, not a copied credential file. A stop signal removes it.
- [expected] An OAuth token refresh rewrites the user's `auth.json` in place through the link; the worker's own tools cannot read it, because reads outside the working and context directories are denied, unless a context directory contains it.
- [expected] Managed or remote organizational configuration can still change effective behavior. The integration is a CLI permission boundary, not an OS sandbox.
- [expected] Polybrief does not re-check the profile at run time. A version check would fire on every frequent OpenCode release, and a hard pin would break after each self-update; the opt-in installed-profile test re-checks the effective configuration after an update. A run-time check of `opencode debug config` is the upgrade path once the worker leaves the experimental stage.
- [expected] `opencode.model` is required: without it OpenCode chooses a model from the available providers, not from the user's own OpenCode settings, and the run report could not name it.

## Superseded when

- OpenCode changes the meaning of `--pure`, `OPENCODE_DISABLE_PROJECT_CONFIG`, or `OPENCODE_CONFIG_CONTENT`.
- OpenCode moves credentials away from `Global.Path.data/auth.json`.
- Polybrief introduces an OS isolation contract for third-party workers.
