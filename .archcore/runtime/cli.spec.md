---
title: "Standalone swarm CLI contract"
status: rejected
tags:
  - "spec"
  - "polybrief"
---

## Purpose & Scope

Replaced on 2026-10-01 by the swarm-cli spec: `bin/swarm` and `scripts/install.sh` were removed when the Go binary passed the parity gate. Kept as the record of the 0.1.0 command line.

Contract for `bin/swarm` and `scripts/install.sh`. The launcher and pattern runner define worker execution; this entry point dispatches to them.

## Surface

Commands: `run`, `review`, `pattern`, `config`, `patterns`, `version`, and `help`. `run` and `review` call the launcher; `pattern` calls the runner. `config` supplies `--show-config`; `patterns` supplies `--list`. Version: `swarm 0.1.0`.

## Normative Behavior

1. The CLI MUST resolve its checkout through symbolic links before dispatching.
2. The CLI MUST preserve supplied arguments, stdin, output, and exit status when dispatching.
3. WHEN `config` is selected, the CLI MUST request the launcher's effective settings.
4. WHEN `patterns` is selected, the CLI MUST request the runner's pattern list.
5. WHEN no command is supplied, the CLI MUST print help without starting a worker.
6. The installer MUST link the checkout's `bin/swarm` into the chosen directory.
7. WHEN the same link exists, the installer MUST leave it unchanged.

## Constraints & Invariants

The installer defaults to `~/.local/bin`. The checkout remains necessary after installation. There is no provider SDK, server, or database dependency. Caller-owned checklist files are supplied explicitly with `--agents-dir`.

## Failure Behavior

1. IF a command is unknown, THEN the CLI MUST exit 2 with a diagnostic.
2. IF another file or link occupies the destination, THEN the installer MUST refuse replacement.

## Conformance

`bash tests/test_cli.sh` verifies symlink installation, relocation, generic briefs, caller-owned checklists, research-stage handoffs, and install conflicts with fake workers.
