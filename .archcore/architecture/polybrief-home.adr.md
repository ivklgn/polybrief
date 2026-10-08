---
title: "Settings, briefs, patterns and checklists are files in one polybrief home"
status: rejected
tags:
  - "architecture"
  - "polybrief"
---

Superseded on 2026-10-07 by @.archcore/architecture/arguments-only-runtime.adr.md after the user chose an argument-only interface.

## Context

After an install, nothing worked without extra files. The README commands pointed at `examples/…/brief.md`, which the release archive and `install.sh` did not ship. `panel` refused to run without `-c review-security.md -c review-tests.md`, files polybrief did not ship either. Settings, patterns, briefs and checklists each had a different lookup: `--config` / `POLYBRIEF_CONFIG` / XDG path, `patterns_dir` / `POLYBRIEF_PATTERNS_DIR` plus patterns embedded in the binary (@.archcore/architecture/go-runtime.adr.md), and paths only for briefs and checklists.

A skill needs to carry its own brief and settings and pass them as arguments, without the user's global files getting in the way. A project needs its own setup too. A file inside the reviewed tree cannot be trusted: a pull request could change the brief or the checklists that review it (@.archcore/runtime/polybrief-config.spec.md).

## Decision

- One folder, the polybrief home, holds `polybrief.conf`, `briefs/`, `patterns/` and `checklists/`. It is `--home DIR`, else `POLYBRIEF_HOME`, else `${XDG_CONFIG_HOME:-~/.config}/polybrief`. polybrief reads one home and never merges two.
- One lookup rule for briefs, patterns and checklists: a name (`a-z`, `0-9`, `-`) is `<kind>/NAME.md` in the home; anything else is a path.
- An argument replaces the home's file for that one thing: `BRIEF`, `-p FILE`, `-c FILE` (same name replaces), `--config FILE`. Everything else still comes from the home.
- With `-b` and no `BRIEF`, the brief is `review`. Every file in `checklists/` is available to a pattern, so `panel` runs without `-c`.
- The defaults are files on disk only. The binary embeds no patterns. @home/ in the repository holds the starter files; the release archive carries them, and @install.sh and @install.ps1 copy each file that does not exist in the home yet, never overwriting one.
- A home inside the reviewed tree is refused, like a settings file there.
- `POLYBRIEF_CONFIG`, `POLYBRIEF_PATTERNS_DIR` and the setting `patterns_dir` are removed.

## Alternatives Considered

1. Keep the defaults embedded in the binary, with an `init` command that copies them out. Rejected by the user: the defaults belong in visible config files.
2. A per-project `.polybrief/` read from the working tree. Rejected: a pull request could change how it is reviewed.
3. A per-project `.polybrief/` read from the `-b` base commit. Deferred: safe, but a harder rule, and it does not apply without `-b`. `--home` covers a project for now.
4. Merge a project home over the global one, file by file. Rejected: two sources for one file make the result hard to predict.

## Consequences

### Positive

- `polybrief -b main` and `polybrief -b main -p panel` work right after `install.sh`.
- Every file polybrief uses is visible and editable in one folder; `polybrief config` prints its `HOME` line.
- A skill passes its own files as arguments, or a whole home with `--home`.

### Negative

- `go install` users get no starter files; the README gives one copy command.
- An update never changes a starter file the user already has, so improved defaults reach only new files or new users.
- Breaking for 0.x users: `POLYBRIEF_CONFIG`, `POLYBRIEF_PATTERNS_DIR` and a `patterns_dir` line stop working; a settings file with `patterns_dir` is refused.
- Briefs and checklists are no longer only caller-owned: polybrief ships two starter checklists (written for polybrief, not taken from ivklgn-kit).