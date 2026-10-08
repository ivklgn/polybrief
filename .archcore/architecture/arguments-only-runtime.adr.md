---
title: "Use command arguments without a polybrief home"
status: accepted
tags:
  - "architecture"
  - "polybrief"
---

## Context

The polybrief home added a settings file, named briefs, patterns, and checklists, plus install-time copying. It made a simple run depend on lookup and override rules across several files (@.archcore/architecture/polybrief-home.adr.md). The user chose an argument-only interface on 2026-10-07 after reviewing what the settings file held. Worker settings already have `-o`; clients and pattern selection already have `-w` and `-p`.

## Decision

- The binary has no polybrief home and reads no polybrief settings file. `--home` and `--config` are removed.
- Each run takes one explicit brief file or `-` for stdin. `-b` adds Git context but does not choose a brief.
- Built-in patterns live in the binary. `-p NAME` chooses one; `-p FILE` uses a caller-owned Markdown pattern written from scratch or copied from an example.
- Checklists are optional caller-owned files passed with `-c FILE`. A pattern that names checklists needs them explicitly.
- `-o KEY=VALUE` changes a setting for one command. `-w` selects worker clients; `polybrief config` shows effective defaults and overrides. `yield` also accepts `-o` for its log path.
- Install scripts install only the binary. Source examples remain examples and are not copied to a global directory.

## Alternatives Considered

1. Keep an optional `--config FILE`. It would preserve saved settings, but the user chose arguments only; all runtime settings already have `-o`.
2. Keep a home for briefs and checklists only. It would retain hidden file lookup and install-time copying.
3. Embed a default review brief and checklists. It would make review shorter, but would mix task-specific review instructions into the general runtime.

## Consequences

A first run needs an explicit brief, for example `printf 'Compare these files. Cite evidence.\n' | polybrief -C repo -`. `go install` and release installs work the same way. `panel` needs two `-c` files named `review-security` and `review-tests`. The caller owns these files and final evidence checks. Prior users of `--home`, `--config`, or implicit `-b` review briefs must pass their inputs and settings on the command line. The release remains read-only; worker isolation is unchanged.