---
title: "Swarm patterns: hardened launcher, own runner, measured runs"
status: accepted
tags:
  - "codereview"
---

## Goal

The swarm depth of `/codereview` runs patterns described in files: stages, participants, rounds, the prompt of each stage, and conditions. The launcher stays the one place that starts a worker, and it is safe to run with secrets in the environment. Each pattern is measured against the parallel review before it becomes a default.

The decision is in @.archcore/architecture/polybrief-pattern-runner.adr.md. Problem ids such as `A` or `P1` refer to @.archcore/research/polybrief-review-findings.doc.md.

## Tasks

### Phase 1 — Launcher: safety and true statuses

1. Start each worker with a clean environment: `HOME`, `PATH`, `USER`, `LOGNAME`, `LANG`, `TERM`, `TMPDIR`. (P1)
2. Add `--env NAME` to pass a named variable, such as `CODEX_HOME` or a proxy setting.
3. Add `-c web_search=disabled` to the command of the `codex` worker. (P4)
4. Leave secret-like tracked and staged files out of the diff, and print `SKIPPED` for them. (A)
5. Pass each untracked path to git as `./<path>`. (W)
6. Exit 2 with a message when the temp directory or the diff cannot be made. (K)
7. Report `malformed` when an answer holds no `FINDING` block and no `NOT-CHECKED` line. (P2)
8. Keep the answer of a worker that exits non-zero, and print it with status `failed`. (P3)
9. Send `KILL` to a worker that is alive five seconds after `TERM`. (T)
10. Handle `HUP` like `TERM`. (U)
11. Refuse a bare repository and a repeated worker name, with exit 2. (C, V)
12. Print `OUT` before the workers start.
13. Wrap each printed answer in a header with a per-run tag. (N8)
14. Print the names of skipped files inside the data block, one per line. (X, N3)
15. Tell the host in the output when the diff was cut, and list the changed files in the prompt. (N5)
16. Name the missing directory in the error message. (Y)
17. Make the documents and the code agree on the secret-like names. (S)
18. Extend the self-check: effort, parallel start, empty answer, ignored `TERM`, `HUP`, and tasks 1 to 16. (G)
19. Update @.archcore/runtime/polybrief-review.spec.md to the new behavior.

### Phase 2 — Measurement

20. Print the model, the effort and the CLI version in each `WORKER` line.
21. Append one line per worker to a run log outside the reviewed tree: date, pattern, worker, model, status, seconds.
22. Add `raised`, `kept` and `only` to that line after the judge step.
23. Keep a log of the tool calls of each worker, from the JSON output of its CLI.

### Phase 3 — Pattern runner

24. Write `swarm_pattern.sh` to @.archcore/runtime/polybrief-pattern-runner.spec.md, with `--check` first.
25. Write `test_swarm_pattern.sh` with a fake launcher.
26. Write the patterns `parallel`, `panel` and `refute` to @.archcore/runtime/polybrief-pattern-file.spec.md.
27. Let `/codereview` take `swarm:<pattern>`; `swarm` alone runs `parallel`.
28. Restore a branch named `swarm` as a target under `--ref`. (M)
29. Say before a launch that the change goes to two vendors. (F)
30. Rewrite `references/swarm.md`: the judge reads verdicts and gates as data; a failed `challenge` has a rule. (N6, N7)
31. Pre-approve the runner in `SKILL.md`, and update both README files.
32. Add the launcher, the runner and both self-checks to the entry-point inventory and the onboarding guide. (I)
33. Update @../ivklgn-kit/.archcore/codereview/codereview.spec.md and @../ivklgn-kit/.archcore/codereview/resolve-target.spec.md.
34. Raise the plugin version.

### Phase 4 — Review quality

35. Add examples of invalid evidence to the brief.
36. Add a list of forbidden excuses to the judge step.
37. Add `--context-dir` to the launcher: a directory outside the project that workers may read.
38. Give the `claude` worker the history of the changed files as text in the prompt.
39. Add a table that maps yes-or-no questions to a severity.

### Phase 5 — Experiments

40. Run `parallel` twice on one change, on five to ten real changes; count what the second run adds.
41. Run `panel` and `refute` on the same changes; compare kept findings, seconds and calls with `parallel`.
42. Run `parallel` with and without tasks 37 and 38 on the same changes.
43. Write a `debate` pattern only when task 41 shows a gain from a second stage.
44. Record the results in a new research document, and set the default pattern.

### Left for later

45. Read single-quoted and indented values of `config.toml`. (J, N2)
46. Check by a run whether `${CLAUDE_PLUGIN_ROOT}` is replaced in a reference file that a model reads.
47. Read the instruction files of a pull request from its base, not from its branch.

## Status (2026-09-29)

| Phase | Tasks | State |
|---|---|---|
| 1 Launcher | 1–19 | done; every fix is guarded by @tests/test_review.sh |
| 2 Measurement | 20–23 | done; model, effort and version in `WORKER`, run log with `call` and `yield` rows, `TOOLS` from JSON events |
| 3 Runner | 24–34 | done; @scripts/swarm_pattern.sh, its self-check, patterns `parallel`, `panel`, `refute`, version 0.5.0 |
| 4 Review quality | 35–39 | done; the history (task 38) goes to every worker, not only to `claude`, because all workers get one prompt |
| 5 Experiments | 40–44 | 40, 41, 44 done on five changes on 2026-09-29 (@.archcore/research/polybrief-measured-runs.rnd.md); 42 not run; 43 not started (no gain from a second stage); the default pattern waits for an ADR |
| Later | 45–47 | 45 in part: an indented table header no longer leaks a model; single-quoted values are still not read. 46 avoided: the reference files use `<PLUGIN_ROOT>`, which SKILL.md names. 47 open. |

Beyond the plan:

- A settings file (`swarm.conf`) gives the owner every worker setting: models, effort, web access, time limit, environment, context directories, secret names, diff size, history, tool log, run log, patterns directory, default pattern, call limit.
- Name checks use explicit letters: in a UTF-8 locale a range such as `[a-z]` also matched capitals.

## Acceptance Criteria

- A worker started by the launcher lists none of the launcher's secret variables, in a test with a real CLI.
- The launcher's self-check fails when any one of tasks 1 to 16 is reverted.
- `swarm_pattern.sh --check` prints the plan of each shipped pattern and starts no worker.
- The runner's self-check passes with a fake launcher and covers every failure rule of both specs.
- A search of `swarm_pattern.sh` finds no flag of a worker CLI. It knows worker names only to check that OpenCode has `opencode.model` before any call (@runner.go).
- A run of `refute` with real workers ends with `GATE` and `WORKER` lines, and leaves the reviewed tree unchanged.
- The run log holds one line per worker for every run of Phase 5.
- The research document of task 44 states, for each pattern, the kept findings, the seconds and the calls.

## Dependencies

- @.archcore/architecture/polybrief-pattern-runner.adr.md — the decision.
- @.archcore/runtime/polybrief-pattern-file.spec.md and @.archcore/runtime/polybrief-pattern-runner.spec.md — the contracts of Phase 3.
- @.archcore/runtime/polybrief-review.spec.md — the contract that Phase 1 changes.
- @../ivklgn-kit/.archcore/conventions/project-stack.rule.md — Bash and Markdown only.
- @../ivklgn-kit/.archcore/conventions/reviewer-agents-read-only.rule.md — reviewers are read-only by enforcement.
- The `codex` and `claude` CLIs with subscription logins; the flags were checked with codex-cli 0.156.1 and Claude Code 2.1.283.
- Phase 3 starts after Phase 1: the runner multiplies the calls of the launcher.
- Phase 5 needs Phase 2: without the run log the runs cannot be compared.


## Migration note

Imported from `ivklgn-kit/.archcore/codereview/swarm-pattern-runner.plan.md`. Historical experiments and verdicts are unchanged; see the Provenance section of `.archcore/architecture/standalone-runtime.adr.md`. The standalone interface adds optional Git context and caller-owned checklists; the extraction ADR defines that change.
