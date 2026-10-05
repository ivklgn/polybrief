---
title: "Engine for the swarm mode of the review gate"
status: draft
tags:
  - "codereview"
---

## Research Goal

Which engine should run a read-only, multi-model review swarm for `/codereview`, from Claude Code and from Codex, on subscription logins?

### Scope

- In scope: ultraswarm, CLI Agent Orchestrator (CAO), metaswarm, other local open-source tools found on 2026-09-27, and the native headless modes of the two CLIs.
- In scope: published evidence on whether several reviewers beat one.
- Out of scope: swarms that write code, cloud services, API-key setups.
- Time box: one session.

## Context & Trigger

- The user wants to try swarm patterns on code review, with a small `swarm` mode of `/codereview` as the test bed.
- The mode has to start the same swarm from Claude Code and, later, from Codex.
- Earlier ideas point the same way: @../ivklgn-kit/.archcore/codereview/ideas/triage-external-review.idea.md (a second opinion from another model) and @../ivklgn-kit/.archcore/codereview/ideas/codex-host-parity.idea.md.

## Questions / Hypotheses

- Question 1: can ultraswarm run a read-only review of an existing diff?
- Question 2: is CAO or metaswarm a better fit?
- Question 3: what is the smallest engine that meets the need?
- Question 4: does evidence support a swarm for review, and which patterns?
- Hypothesis 1: a chat assistant's description of ultraswarm (roles such as `consensus_voter`, fields such as `swarm_role`) is accurate. It would be disproved by the repository.

## Approach

### Inputs

- Repositories read from shallow clones, nothing installed: `fubak/ultraswarm` at `fe11309`, `awslabs/cli-agent-orchestrator` at `7833115`, `dsifry/metaswarm` at `33d39f7`.
- GitHub metadata through `gh` on 2026-09-27.
- Local `--help` output of codex-cli 0.156.1 and Claude Code 2.1.283.
- Papers and vendor posts listed under Related Materials.

### Options

- Option A: ultraswarm as the engine.
- Option B: CAO as the engine.
- Option C: metaswarm, or only its Codex adapter.
- Option D: a ready review tool — `openai/codex-plugin-cc` or `raine/consult-llm`.
- Option E: a thin Bash launcher over `codex exec` and `claude -p`.

### Experiments

- Experiment 1: run each CLI headless on the subscription login with a one-word task.
- Experiment 2: ask each worker to create a file under its read-only flags.
- Experiment 3: put a `SessionStart` hook into the reviewed tree and see whether a worker runs it.
- Experiment 4: run the launcher with both real workers on the change that adds the mode.
- Experiment 5: ask the Codex worker to call an MCP tool, with and without the user config.
- Experiment 6: install ultraswarm at the commit that was read, and run the same review through it.

## Findings

### Tools

| Tool | What it is | Review-only mode | Drives workers by | Reviewer models | Weight | Activity |
|---|---|---|---|---|---|---|
| ultraswarm | Node 22 CLI for code-writing tasks in worktrees | none; a worker that changes no file fails (`implement.mjs:143-148`) | headless calls with write flags | Claude only; other CLIs only write | SQLite state, worktrees, merges | 83 stars, 1 contributor, last commit 2026-07-03 |
| CAO | Python server + tmux + MCP | possible with own profiles; Codex restriction is prompt-only by default | interactive TUIs in tmux, screen scraping | any provider per profile | running server, tmux, uv | 1352 stars, 72 contributors, active |
| metaswarm | prompt pack + two Bash adapters | adapter `review` is read-only, needs a spec file, diffs only `HEAD` | host subagents; `codex exec --sandbox read-only` | Codex and Gemini as external; no Claude adapter | hooks and repo files after setup | 420 stars, one author, last commit 2026-06-19 |
| codex-plugin-cc | official Claude Code plugin | yes (`/codex:review`, `/codex:adversarial-review`) | Codex app server | Codex only | plugin, Node | 33,625 stars, last commit 2026-07-08 |
| consult-llm | Rust CLI + skills | yes (`review-panel`) | `codex exec`, `claude -p` | several | extra binary | 139 stars, last commit 2026-09-22 |
| thin launcher | one Bash script | yes | `codex exec`, `claude -p` | Codex and Claude | none | own code |

- Finding 1: Hypothesis 1 is false. `worker_id`, `cli_command`, `swarm_role`, `system_instruction` and `consensus_voter` have no match in the ultraswarm repository; the word "consensus" has none either.
- Finding 2: ultraswarm has no read-only path. Its health probe requires a worker to write a file (`lib/workers/smoke.mjs`), and reviewer findings are not stored as structured data.
- Finding 3: CAO starts workers with full permission bypass by default and sets `skipDangerousModePermissionPrompt` in `~/.claude/settings.json` on each Claude start (`providers/claude_code.py:534-587`).
- Finding 4: option D tools run from Claude Code only, so they do not give one swarm for two hosts.

### Experiments

- Experiment 1: both CLIs answered on the subscription login — Codex in about 10 s, Claude in about 5 s.
- Experiment 2: both workers refused to create a file. Codex used `-s read-only`; Claude had `--tools "Read,Grep,Glob"`.
- Experiment 3: with `--setting-sources project` the hook of the reviewed tree ran in the Claude worker. With `--setting-sources ""` it did not. Codex did not run the untrusted project hook.
- Experiment 3, side result: `--bare` is not usable, because it reads only `ANTHROPIC_API_KEY` (Claude `--help`).
- Experiment 4: both workers answered, Codex in 166 s (84,305 tokens) and Claude in 319 s. Details under "Dogfood run".
- Experiment 5: with the user config, the Codex worker called `archcore/list_documents` in the read-only sandbox, with no approval (log line `mcp: archcore/list_documents (completed)`). With `--ignore-user-config` it had no such tool and ran no hook.
- Experiment 5, side result: `--ignore-user-config` changed the model from `gpt-6-sol` with `medium` effort to `gpt-6-astra` with effort `none`, so the launcher passes the user's values by hand.
- Experiment 5, side result: the worker's own list of its tools did not match the log. A tool list reported by a model is not evidence.

### ultraswarm (Experiment 6)

The user asked for the same scenario on ultraswarm, next to the launcher. ultraswarm 3.6.1 at `fe11309` was installed from a clone, with `npm ci --ignore-scripts`.

Two versions were built. The first put ultraswarm behind the launcher, in a throwaway clone, with its review stage off; it was removed when the user asked for ultraswarm without a script in between. The second called ultraswarm directly (@.archcore/architecture/ultraswarm-optional-engine.adr.md); it was removed on 2026-09-29.

Results of the direct version, followed by hand on a test project with one planted defect:

| Run | Review stage of ultraswarm | Attempts | Wall time |
|---|---|---|---|
| 1 | accepted both results | codex 1, claude 1 | 128 s |
| 2, with checklists | rejected one attempt of claude, then accepted | codex 1, claude 2 | 426 s |

- Both workers found the planted defect in both runs.
- ultraswarm does not record why its review stage rejected an attempt; the reason of the rejection in run 2 is not known.
- A hostile `pre-commit` hook and a `postinstall` script in the test project did not run.
- After the clean-up commands the test project had its one worktree and no `ultraswarm/*` branch.
- A Claude worker with a shell limited to `git diff`, `git log` and `git show` could not create a file. The limit was still not used, because `git diff --output=<file>` writes a file.

The first version needed four of ultraswarm's rules worked around; the direct version keeps the first three and leaves the review stage on:

| Rule of ultraswarm | Source | How the launcher meets it |
|---|---|---|
| A task without file changes fails | `lib/orchestrator/implement.mjs:143-148` | the worker's command copies its final message into the worktree; the model stays read-only |
| The worker prompt is cut at 64,000 characters | `lib/prompts.mjs:39` | the command feeds the full prompt from a file on stdin |
| A worker command has to name `.ultraswarm-prompt.txt` | config validation in `lib/router.mjs` | the command reads that file first, then the full prompt |
| Claude reviews every task result as a code change | `lib/orchestrator/runner.mjs:54-63` | first version: `ULTRASWARM_BRAIN=mock`, the approving test brain; direct version: left on |

- Claude Code is not a built-in worker; it was added as a config alias.
- The `ultraswarm` command that `npm link` creates does nothing and exits 0: `bin/ultraswarm.mjs` compares `import.meta.url` with `process.argv[1]`, and a symlink makes them differ. The entry file has to be started with `node`.
- What ultraswarm adds in the direct version: worktrees, process supervision, retries (up to three), its review stage with a retry on rejection, a run record in SQLite, and a report with token counts for Codex.
- What it does not add: its plan decomposition, routing and competition have no use here.
- In a project with a root lockfile ultraswarm installs dependencies in every worktree (`lib/orchestrator/worktree-deps.mjs`); no switch exists. An install runs the install scripts of the reviewed code, so the launcher leaves root lockfiles out of the clone.
- ultraswarm takes the limit of a worker run from the top-level `timeoutMs` and `timeouts` of its config (`lib/orchestrator/implement.mjs:80`), not from `overrides.<cli>.timeoutMs`.
- ultraswarm passes only a fixed list of environment variables to a worker; `CODEX_HOME` is not in it and has to be added through `workerEnvAllowlist`.
- `npm audit` reports one high-severity advisory in its dependency `fast-uri`.

### Dogfood run

The first version of the launcher was reviewed by its own swarm.

| | Codex | Claude |
|---|---|---|
| Raised, without questions | 2 | 10 |
| Kept after verification | 2 | 10 |
| Only this worker | 0 | 8 |
| Raised by both | 2 | 2 |
| Questions | 0 | 2 |

- Both workers found the two most serious problems on their own: MCP tools open to the Codex worker, and untracked files with quoted names missing from the change.
- Both problems were reproduced before the fix: the first by Experiment 5, the second with a file with a Cyrillic name.
- The workers disagreed on severity for both: Codex said blocker, Claude said major and minor. The rubric of the skill gives blocker for both.
- Claude, with no shell, found eight more problems; all held against the code. Nine of the ten findings were fixed, and one was accepted as a documented limit (a branch named `swarm`). Both questions led to a change.
- One run on one change is an example, not a measurement.

### Second dogfood run, through the first ultraswarm version

The change that added the first ultraswarm version was reviewed through it, with four checklists.

| | Codex | Claude |
|---|---|---|
| Time | 206 s | 565 s |
| Raised, without questions | 5 | 11 |
| Kept after verification | 4 | 11 |
| Only this worker | 2 | 9 |
| Raised by both | 2 | 2 |
| Questions | 0 | 1 |

- Both found that ultraswarm would run the install scripts of the reviewed code, and that the `config.toml` reader took a model from a profile.
- Only Codex found that `--timeout` never reached ultraswarm and that `CODEX_HOME` was dropped. Both were confirmed in the ultraswarm source.
- One Codex blocker was rejected: a retry on the other worker cannot happen for these tasks, because low-risk tasks take the path without alternates (`lib/orchestrator/runner.mjs:65-102`). The status check was still tightened.
- Only Claude found the silent failure of the engine with a copy left on disk, the two meanings of exit 1, and the missing ADR.
- Codex graded four of its five findings as blocker; Claude graded none of its eleven as blocker.

### Evidence on multi-reviewer review

- Aggregating several reviews raised F1 by up to 43.67% on 1000 verified PRs (SWR-Bench, arXiv 2509.01494).
- Cross-model review helped in one direction only: Claude reviewing Codex 71.6% → 89.7%, Codex reviewing Claude 91.4% → 82.8%, on 116 tasks (arXiv 2607.21656).
- Majority voting explains most of the gain of multi-agent debate (arXiv 2508.17536); debate does not reliably beat ensembling (arXiv 2311.17371).
- Models agree 60% of the time when both err, also across providers (arXiv 2506.07962).
- Ten reviewers endorsed a bug that did not exist; an empirical test removed it (arXiv 2604.19049, practitioner report).
- Most of this evidence comes from QA and reasoning benchmarks; its transfer to code review is an inference.

## Implications

- The engine is small: parallel headless calls, one shared prompt, read-only flags, a timeout. None of the studied orchestrators adds a needed part.
- The value is in the judge, not in the fan-out: agreement is not proof, so every serious finding still goes through Step 8 verification.
- Debate rounds are left out. One refutation round on request (`challenge`) is the most the evidence supports.
- The report has to show per-worker yield, or the experiment teaches nothing.

## Recommendation

**proceed** — option E, a thin Bash launcher, for the depth `swarm`. It is the only option that is read-only by enforcement, host-neutral, inside the project stack (@../ivklgn-kit/.archcore/conventions/project-stack.rule.md) and free of new dependencies. The `ultraswarm` depth, kept at first for comparison, was removed on 2026-09-29. The later research is in @.archcore/research/polybrief-pattern-layer.rnd.md, the decision in @.archcore/architecture/polybrief-pattern-runner.adr.md.

## Next Action

- [ ] Follow @.archcore/runtime/polybrief-pattern-runner.plan.md; its Phase 5 holds the runs on five to ten real changes.

## Risks & Unknowns

- Risk 1: Claude Code documentation says `--bare` is planned as the default for `-p`. The `claude` worker then loses the subscription login. The launcher reports it as `failed` and the review goes on with Codex.
- Risk 2: a run takes minutes and spends subscription quota of two products.
- Risk 3: the judge is one model and can favor findings close to its own reasoning.
- Risk 4: the Codex worker keeps its built-in web tool; no switch for it was found in `codex features list`.
- Unknown 1: whether the swarm finds more real problems than the standard lanes. Only repeated use answers this.
- Unknown 2: closed. ultraswarm, metaswarm and CAO were run on one change on 2026-09-28; the results are in @.archcore/research/polybrief-pattern-layer.rnd.md.

## Related Materials

- https://github.com/fubak/ultraswarm
- https://github.com/awslabs/cli-agent-orchestrator
- https://github.com/dsifry/metaswarm
- https://github.com/openai/codex-plugin-cc
- https://github.com/raine/consult-llm
- https://github.com/EveryInc/compound-engineering-plugin
- https://github.com/nyldn/claude-octopus
- https://arxiv.org/abs/2509.01494, https://arxiv.org/abs/2607.21656, https://arxiv.org/abs/2508.17536, https://arxiv.org/abs/2311.17371, https://arxiv.org/abs/2506.07962, https://arxiv.org/abs/2604.19049
- https://claude.com/blog/code-review
- @scripts/swarm_review.sh, @../ivklgn-kit/skills/codereview/references/swarm.md

## Migration note

Imported from `ivklgn-kit/.archcore/codereview/swarm-review-engine.rnd.md`. Historical experiments and verdicts are unchanged; see the Provenance section of `.archcore/architecture/standalone-runtime.adr.md`. The standalone interface adds optional Git context and caller-owned checklists; the extraction ADR defines that change.
