---
title: "Pattern layer for the swarm mode of the review gate"
status: draft
tags:
  - "codereview"
---

## Research Goal

Should the kit keep its own swarm launcher and build a pattern layer on it, or replace both with an existing open-source tool?

### Scope

- In scope: tools that run agent CLIs for a read-only review on subscription logins, and ways to describe swarm patterns.
- In scope: how much the findings change between runs of the same review.
- Out of scope: swarms that write code, cloud services, API-key setups.
- Dates: 2026-09-27 to 2026-09-28.

## Context & Trigger

- The first research (@.archcore/research/polybrief-review-engine.rnd.md) chose a thin Bash launcher and left three tools unrun.
- The owner then asked for configurable swarm behaviour: patterns, rounds, roles and prompts per stage, and conditions.
- The launcher runs one prompt once. The one pattern of today is written into @../ivklgn-kit/skills/codereview/references/swarm.md.

## Questions / Hypotheses

- Question 1: does any open-source tool meet all nine requirements below?
- Question 2: which tools can describe a pattern in a file, and does a program or a model walk it?
- Question 3: what does a launcher change in time and findings, with the prompt and the models fixed?
- Question 4: how stable are the findings between runs of one review?
- Hypothesis 1: a wider search finds a ready tool. It would be confirmed by one candidate that passes R1, R2, R5 and R9 together.

## Approach

### Requirements

| Id | Requirement |
|---|---|
| R1 | reviewers cannot write, by CLI flags or a sandbox |
| R2 | no user or project agent setup reaches a reviewer |
| R3 | runs from Claude Code, from Codex and from a terminal |
| R4 | subscription logins, no API keys |
| R5 | two vendors review the same change in parallel |
| R6 | own prompt in, raw answer per reviewer out, with status and time |
| R7 | reviews base to working tree, with untracked files |
| R8 | no server, no database |
| R9 | patterns, rounds, roles and conditions are described without a code change |

### Inputs

- About 600 rows of GitHub search results, 80 shallow clones, 15 candidates read in the code that starts the CLIs.
- One change: the swarm depth of this kit, 18 files, 1194 added lines, a diff of 99 KB.
- One prompt of 116 KB for every same-prompt run: brief, four checklists, the change.
- Models: `gpt-6-sol` with effort `medium`, and the default model of Claude Code 2.1.283.
- Every run worked on a copy of the repository outside the project.

### Experiments

- Experiment 1: run ultraswarm, metaswarm and CAO on the change.
- Experiment 2: install six candidates outside the home directory and run each with the same prompt.
- Experiment 3: run the pattern feature of the four candidates that have one.
- Experiment 4: map the findings of all runs to problems and count them per run.
- Experiment 5: probe the launcher itself with real and fake workers.

## Findings

### Candidates

| Candidate | R1 | R2 | R5 | R6 | R9 |
|---|---|---|---|---|---|
| the kit's launcher | yes | yes | yes | yes | one fixed pattern |
| heggria/taskflow | yes | yes | no | partly | yes |
| crewplaneai/crewplane | partly | partly | yes | yes | yes |
| aarondfrancis/counselors | yes | partly | yes | yes | rounds only |
| Lexus2016/consilium | yes | partly | yes | partly | two fixed recipes |
| raine/consult-llm | partly | no | yes | partly | skills that a host model follows |
| devdacian/touchstone | yes | partly | partly | partly | text that a host model follows |

- Finding 1: Hypothesis 1 is false. No candidate passes R1, R2, R5 and R9 together.
- Finding 2: the tools fall into two groups: launchers with safe flags and a fixed pattern, and pattern engines that leave permissions to the user.
- Finding 3: no candidate builds a diff of base to working tree with untracked files and a filter for secret-like names.

### Same-prompt runs (Experiment 2)

| Tool | Wall time | Codex | Claude | Notes |
|---|---|---|---|---|
| the kit's launcher | 453 s | 164 s | 454 s | |
| consult-llm | 221 s | 130 s | 221 s | puts two text blocks of its own before the prompt |
| taskflow | 463 s | 193 s | 463 s | needed a driver script; it has no command that runs a flow |
| consilium | 509 s | 137 s | 509 s | links the Codex login file into a clean home |
| touchstone | 511 s | 139 s | 511 s | Codex made 3 MCP calls; the Claude model and effort are pinned |
| crewplane | 517 s | 221 s | 516 s | needed three workarounds |
| counselors | 521 s | 209 s | 521 s | built-in adapters turn the web tools on |

- Finding 4: every run ended with two answers and an unchanged copy of the repository.
- Finding 5: the reference flags of the launcher had to be written again in the settings of five tools out of six.
- Finding 6: with the prompt and the models fixed, the launcher changes little. The one fast run is a single measurement with no known cause.

### Pattern runs (Experiment 3)

| Tool | Pattern | Calls | Wall time | Who walks the steps |
|---|---|---|---|---|
| taskflow | review, cross refutation, gate | 4 | 690 s | a program, from a JSON graph |
| crewplane | review, cross check | 4 | 639 s | a program, from Markdown with a YAML header |
| counselors | loop of two rounds | 4 | 1131 s | a program, from command-line flags |
| consult-llm | one refutation round | 2 | 166 s | the test script; its own patterns need a host model |

- Finding 7: taskflow checked each refuter's answer against a contract and ended with a gate that called no model.
- Finding 8: crewplane has no condition and no gate for parallel nodes, and one node cannot send different prompts to its providers.
- Finding 9: taskflow runs one vendor per flow; the mixed flow needed a small router written for the test.

### Earlier runs (Experiment 1)

| Tool | Result |
|---|---|
| ultraswarm | 637 s, both attempts accepted; 1342 s in another session with one rejected attempt |
| metaswarm | 113 s for its Codex adapter and 853 s for the Claude part; a first attempt lost 816 s |
| CAO | four attempts, no review through its API |

- ultraswarm starts its review stage as `claude -p` with no tool or settings limit (`lib/llm/claude-cli.mjs:25-28`, commit `fe11309`).
- CAO starts workers with permission bypass by default; both workers stopped at start dialogs that it does not handle.
- CAO reported `completed` after 13 seconds and returned the first sentence of Codex as the answer.

### Stability of findings (Experiment 4)

Nine runs with the same prompt. The mapping of findings to problems is a judgment.

| Measure | Codex | Claude |
|---|---|---|
| Distinct problems in one run | 2 to 3 | 6 to 11 |
| Distinct problems in nine runs | 11 | 20 |
| Problems in at least five runs | 1 | 7 |
| Problems in one run only | 6 | 6 |
| Mean overlap of two runs (Jaccard) | 0.18 | 0.49 |
| Share of findings graded blocker | 77% | 1% |

- Finding 10: the two reviewers share 2 of 29 problems.
- Finding 11: one Claude run gives 44% of what nine runs give; one Codex run gives 22%.
- Finding 12: seven known problems appeared in no same-prompt run. Runs with another prompt and wider read access found them.
- The full list is in @.archcore/research/polybrief-review-findings.doc.md.

### The launcher (Experiment 5)

- A Codex worker saw every variable of the launcher's environment, among them names ending in `_API_KEY` and `_SECRET_TOKEN`.
- The owner's shell holds three such variables. No earlier worker log contains their names.
- Codex logs in with `HOME` and `PATH` only. Claude needs `USER` as well.
- `-c web_search=disabled` turned the web tool of Codex off: two web calls without it, none with it.
- A worker that ignores `TERM` kept the launcher waiting 8 to 12 seconds at a limit of 2 seconds, in five runs of six.
- The launcher reports `ok` for any non-empty text, and drops an answer that comes before a non-zero exit.
- `--setting-sources=` has the same effect as an empty argument: only built-in plugins load, and no hook runs.

## Implications

- Replacing the launcher gains nothing: the safety of every candidate came from the launcher's own flags.
- A pattern engine from outside means a second copy of those flags. Reviewers already reported such a copy as a problem.
- A repeat of a run adds more findings than another tool does.
- A pattern language larger than about ten settings has no support in the evidence on review.

## Recommendation

**proceed** — keep the launcher, harden it, and add the kit's own pattern runner: stages and answer routing after crewplane, an answer contract and a gate after taskflow. The decision is in @.archcore/architecture/polybrief-pattern-runner.adr.md.

## Next Action

- [ ] Follow @.archcore/runtime/polybrief-pattern-runner.plan.md.

## Risks & Unknowns

- Risk 1: no candidate was tested under failure: subscription limits, timeouts, lost network.
- Risk 2: the field changes fast; the search reflects 2026-09-28.
- Risk 3: the runner can grow into an engine. The limits of the format are the guard.
- Unknown 1: whether patterns beyond parallel review and one refutation round find more real problems.
- Unknown 2: whether wider read access explains the extra findings of metaswarm.
- Unknown 3: GitLab, npm and PyPI were not searched directly.

## Related Materials

- https://github.com/heggria/taskflow
- https://github.com/crewplaneai/crewplane
- https://github.com/aarondfrancis/counselors
- https://github.com/Lexus2016/consilium
- https://github.com/devdacian/touchstone
- https://github.com/raine/consult-llm
- https://github.com/fubak/ultraswarm, https://github.com/dsifry/metaswarm, https://github.com/awslabs/cli-agent-orchestrator
- https://code.claude.com/docs/en/workflows
- https://arxiv.org/abs/2509.01494, https://arxiv.org/abs/2608.18167, https://arxiv.org/abs/2508.17536
- @scripts/swarm_review.sh, @../ivklgn-kit/skills/codereview/references/swarm.md


## Migration note

Imported from `ivklgn-kit/.archcore/codereview/swarm-pattern-layer.rnd.md`. Historical experiments and verdicts are unchanged; see the Provenance section of `.archcore/architecture/standalone-runtime.adr.md`. The standalone interface adds optional Git context and caller-owned checklists; the extraction ADR defines that change.
