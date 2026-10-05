---
title: "Problems found by the swarm test runs"
status: draft
tags:
  - "codereview"
---

## Overview

The list of problems that the test runs of 2026-09-27 and 2026-09-28 found in the change that added the swarm depth. It is the backlog for @.archcore/runtime/polybrief-pattern-runner.plan.md. The runs and their method are in @.archcore/research/polybrief-pattern-layer.rnd.md.

- Reviewed state: the working tree of 2026-09-27, before the `ultraswarm` depth was removed. Line numbers refer to that state.
- "Runs" counts the nine runs that used the same prompt: Codex, then Claude. "other" means only a run with a different prompt found it.
- "Checked" says how the claim was confirmed: `run` (reproduced by a command), `read` (the code was read), `probe` (a small command on the side).
- The mapping of findings to problems is a judgment.

## Content

### Status on 2026-09-29

- Fixed and guarded by a self-check: A, C, G, I, K, M, N2, N3, N5, N6, N7, N8, P1, P2, P3, P4, S, T, U, V, W, X, Y.
- Mitigated: F — the skill names the pattern and the two vendors before each launch; the word `swarm` still selects the depth.
- Open: J — single-quoted values of `config.toml` are not read; the setting `codex.model` covers it.
- The questions below stay open, except `${CLAUDE_PLUGIN_ROOT}` (the reference files now use `<PLUGIN_ROOT>`) and the plugin version (now 0.5.0).

### Open problems of the launcher

| Id | Where | Problem | Checked | Runs |
|---|---|---|---|---|
| A | `swarm_review.sh:90` | the secret-name filter covers untracked files only; tracked and staged ones go into the prompt | read | 6, 3 |
| C | `swarm_review.sh:50` | a bare repository passes the work-tree check; the script exits 128, not 2 | run | 2, 0 |
| J | `swarm_review.sh:134` | only double-quoted, unindented TOML values are read; a known simplification | read | 1, 0 |
| K | `swarm_review.sh:76` | a failure of `mktemp` or of the diff exits 1, the code for "no worker answered" | run | 0, 7 |
| S | `swarm_review.sh:83` | documents say `.env*`; the code skips `.env` and `.env.*`, so `.envrc` is sent | read | 0, 3 |
| T | `swarm_review.sh:146` | the watchdog sends `TERM` only; a worker that ignores it outlives the limit | run, 5 of 6 | other |
| U | `swarm_review.sh:179` | the trap does not handle `HUP` | read | other |
| V | `swarm_review.sh:59` | `--workers codex,codex` is accepted; two jobs write one answer file | run | 2, 1 |
| W | `swarm_review.sh:94` | an untracked file named `-` removes every untracked file from the prompt, with exit 0 | run | other |
| X | `swarm_review.sh:121` | names of skipped files are printed outside the data block of the prompt | read | other |
| Y | `swarm_review.sh:49` | the error for a missing directory prints an empty name | run | other |
| N2 | `swarm_review.sh:134` | an indented table header does not end the top-level keys | probe | 1, 0 |
| N3 | `swarm_review.sh:91` | a newline in a skipped file name gives several `SKIPPED` lines | read | 1, 0 |
| N5 | `swarm_review.sh:117` | a cut diff gives the host no signal and the workers no list of files | read | 0, 3 |
| N8 | `swarm_review.sh:189` | an answer can contain the fixed `=== name ===` line | read | 0, 2 |

### Open problems found by probes of the launcher

| Id | Problem | Checked |
|---|---|---|
| P1 | a worker inherits the whole environment of the launcher, secrets included | run |
| P2 | any non-empty text is reported as `ok`, for example "Please run /login" | run |
| P3 | an answer written before a non-zero exit is dropped | run |
| P4 | the web tool of Codex is on; `-c web_search=disabled` turns it off | run |

### Open problems of the skill text, the resolver and the documents

| Id | Where | Problem | Checked | Runs |
|---|---|---|---|---|
| F | `scripts/resolve_target.sh:89` | `swarm` as a focus word selects the depth and starts the launcher | read | 0, 3 |
| M | `scripts/resolve_target.sh:89` | with `--ref`, a branch named `swarm` is no longer a target; `/load swarm` loads the current branch | run | 0, 5 |
| G | `test_swarm_review.sh` | the self-check guards neither the effort, nor the parallel start, nor an empty answer | read | 0, 9 |
| I | `.archcore/architecture/entry-points.doc.md` | the inventory and the test list of the onboarding guide lack the new script | read | 0, 9 |
| N6 | `references/swarm.md:118` | a failed `challenge` has no failure rule | read | 0, 1 |
| N7 | `references/swarm.md:97` | the judge rule drops the `NOT-CHECKED` lines of the workers | read | 0, 1 |

### Closed by the removal of the `ultraswarm` depth

| Id | Problem |
|---|---|
| B | the clean-up deleted every `ultraswarm/*` branch, also of another run |
| D | `$RUN` and `$US` did not survive separate shell calls; a commit could land in the user's checkout |
| E | the write invariant of the skill was not extended for the worktree, the commit and the branches |
| H | the isolation flags had a second copy in `ultraswarm.config.json` that no check guarded |
| L | a `.swarm-review/` directory of the reviewed commit reached the workers as trusted checklists |
| N | an empty findings file counted as an answer |
| O | `change.diff` was built without the guard against the user's diff settings |
| P | `git worktree add` ran before the hook guard |
| Q | the review stage of ultraswarm started `claude -p` with no tool or settings limit |
| R | a global ultraswarm config could replace the read-only worker command |
| Z | a leftover run directory broke the next run on the same commit |
| N1 | the list of removed lockfiles had three names; the risk did not hold at commit `fe11309` |
| N4 | the install of ultraswarm was not pinned to a commit |
| N9 | `challenge` in that depth saw the working tree, the depth itself only commits |
| N10 | the re-run rule assumed uncommitted fixes, the depth reviewed commits only |

### Questions of the reviewers, not checked

| Topic | Claude runs |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}` in reference files: is it replaced when a model reads the file? | 6 of 9 |
| instruction files of a pull request, together with the web tool of Codex | 3 of 9 |
| a byte cut of the diff inside a UTF-8 character | 1 of 9 |
| the plugin version was not raised | 1 of 9 |

### Counts

| Group | Problems |
|---|---|
| open, launcher | 15 |
| open, probes | 4 |
| open, skill text, resolver, documents | 6 |
| closed by removal | 15 |

### How often one run finds a problem

| Measure | Codex | Claude |
|---|---|---|
| Findings in nine runs | 22 | 80, and 27 questions |
| Distinct problems in one run | 2 to 3 | 6 to 11 |
| Distinct problems in nine runs | 11 | 20 |
| Problems in at least five runs | A | D, E, G, I, K, M, O |
| Distinct problems after runs 1 to 9 | 3, 4, 6, 8, 8, 10, 10, 11, 11 | 6, 10, 12, 15, 17, 18, 19, 19, 20 |
| Grades: blocker, major, minor | 77%, 5%, 18% | 1%, 20%, 79% |

## Examples

- Problem W, reproduced: a repository with the untracked files `-`, `m.txt` and `z.txt` gives a prompt that holds none of the three, and the launcher exits 0.
- Problem M, reproduced: with a local branch `swarm`, `resolve_target.sh --ref --args 'swarm'` prints `KIND local` and `FOCUS swarm`; the version before the change printed `KIND branch`.
- Problem P1, reproduced: a worker started with the launcher's flags listed four test variables, two of them with names of secrets.


## Migration note

Imported from `ivklgn-kit/.archcore/codereview/swarm-review-findings.doc.md`. Historical experiments and verdicts are unchanged; see the Provenance section of `.archcore/architecture/standalone-runtime.adr.md`. The standalone interface adds optional Git context and caller-owned checklists; the extraction ADR defines that change.
