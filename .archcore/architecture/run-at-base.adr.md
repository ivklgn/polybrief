---
title: "Run a participant at base, and embed the intent pattern"
status: accepted
tags:
  - "architecture"
  - "polybrief"
---

## Context

The `intent` idea compares two independent descriptions of a change: `intended` states what the task asks without seeing the change, `built` describes the change without seeing the task, and a judge matches the two lists. Before this decision a run could not keep one participant away from the change: with `-b`, every participant got the same prepared diff (@runner.go `execute`) and worked in the same directory, the tree after the change.

The experiment in @.archcore/research/intent-pattern-experiment.research.md ran the pattern with a hand-made base tree and no `-b`. It found both seeded defects as the judge's first `CONFLICT` row, at 97–159 s and 172k–292k input tokens per run. It also listed what the workaround lacks: `built` reads the base tree instead of the tree after the change, the diff skips the secret-name filter and `max_diff_bytes`, and the caller builds the tree by hand.

ivklgn-kit already calls the built-in pattern: its integration contract (accepted, commit `d116797`, 2026-10-13) runs `polybrief -b <MERGE_BASE> -p intent -c task.md` and reports `intent: not run` while polybrief does not list `intent`. A kit may not pass a pattern file, so only a built-in pattern serves it.

Fact checked on 2026-10-15: `codex exec -C <dir>` refuses a directory outside Git ("Not inside a trusted directory and --skip-git-repo-check was not specified") and accepts a directory after `git init` alone, with no commit.

## Decision

1. A `run` line takes `at base`: `run: <worker> [as <role>] [at base] [with …]`.
2. For such a participant the runner unpacks the base commit with `git archive` (stdlib `archive/tar`) into `TMPDIR/polybrief-base.*`, runs `git init` there, and passes that directory as `--dir` with no prepared context. The launcher is unchanged. Links are created after every file, through `os.Root`, so a crafted commit cannot make the runner write outside the base tree.
3. The runner resolves `-b` to one commit first, so the diff and the base tree take the same commit.
4. A run with `at base` and no `-b` exits 2 before `OUT` exists; `polybrief plan` does not need `-b`.
5. The base tree is removed when the run ends or on a stop signal.
6. Reversed on 2026-10-22, see Revision: `intent` becomes a built-in pattern: `codex as intended at base with task`, `claude as built with none`, then `claude as judge` over both answers, the task, an optional `spec` checklist and the diff. 3 calls.

## Alternatives

- **Two runs and a judge at the caller.** Works today (the experiment), but the judge stage leaves polybrief and ivklgn-kit cannot use it, because a kit may not pass a pattern file.
- **`git worktree add` at base.** Gives a real checkout, but writes to `.git` of the reviewed repository, and the worktree sees all history, so future commits are reachable.
- **A snapshot without `.git` plus `--skip-git-repo-check` for codex.** One flag less in the snapshot, but the flag would reach every codex run of the launcher and turns off a codex check for all of them.
- **A one-commit repository in the snapshot.** Used in the experiment. `git add` hashes every file, and `git commit` depends on the user's identity, signing and hooks. Not needed: codex accepts `git init` alone.

## Revision 2026-10-22

Point 6 is reversed. @.archcore/research/intent-baseline-spike.rnd.md compared the three-call blind form with a one-stage `parallel` form that gives both workers the task and the diff and the same row format: the one-stage form found both seeded defects in all four answers, every true row of the clean changes and four more, at 41–92 s against 75–97 s. The built-in `intent` is now that one-stage form (2 calls, `expect` on the rows, `-w` replaces workers). Points 1–5 stand: `at base` stays in the runtime and its contracts, checked end to end by @tests/test_cli.sh with a custom pattern; no built-in pattern uses it.

## Consequences

- Reversed on 2026-10-22: the kit's intent pass runs as soon as this release is installed; no kit change is needed. Superseded by the 2026-10-22 revision: the one-stage `intent` needs the kit's row-format brief, so ivklgn-kit and polybrief 0.0.4 ship together. A kit brief that asks for `ITEM` lines gets `malformed` answers from the one-stage pattern.
- Isolation is by directory and prompt, not by sandbox: a read-only worker could still read other paths on the machine, such as `OUT/change.json` or the reviewed repository.
- The base tree has what `git archive` gives: no files marked `export-ignore`, no submodule contents. Links that the system refuses (Windows without the right) or whose path would leave the tree are skipped. Of two names that differ only in case, a case-insensitive filesystem keeps the first.
- The base tree is removed on every exit of the runner: the end of the run, an exit 2 (`die`) and a stop signal, also while it is being unpacked. Only a kill the process cannot catch (SIGKILL) leaves it in `TMPDIR`.
- The checklist wrapper text ("the method of one specialist reviewer") still frames the task file; the brief has to tell the workers to ignore it.
- Specs updated: @.archcore/runtime/polybrief-pattern-file.spec.md (grammar, 7a, 8i), @.archcore/runtime/polybrief-pattern-runner.spec.md (2a, 25–28, failures 14–15), @.archcore/runtime/polybrief-cli.spec.md (5). Tests: @tests/test_cli.sh (end-to-end with fake workers; since the 2026-10-22 revision on a custom pattern with `at base`), @tests/test_pattern.sh (refused `at` value).
- Still open from the experiment: the miss rate on subtle defects and run-to-run variance were measured on two seeded changes only.
