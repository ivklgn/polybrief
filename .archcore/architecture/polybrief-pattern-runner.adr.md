---
title: "Swarm patterns run on the kit's own pattern runner"
status: accepted
tags:
  - "codereview"
---

## Context

The swarm depth of `/codereview` knows one pattern: independent reviewers in parallel, then the host as judge. The pattern is written into @../ivklgn-kit/skills/codereview/references/swarm.md, and the launcher (@scripts/swarm_review.sh) runs one prompt once.

The owner asked for configurable swarm behaviour: different patterns, the number of rounds, the roles and the prompt of each stage, who receives whose answer, and conditions such as "a second round only for blockers".

The research (@.archcore/research/polybrief-pattern-layer.rnd.md) read 15 open-source candidates and ran six of them, after ultraswarm, metaswarm and CAO. The result:

- No tool gives read-only reviewers, isolation, two vendors in parallel and a pattern language together.
- Two engines walked a pattern file by program: taskflow and crewplane. Each needed workarounds, and the isolation flags of the launcher had to be written again in their settings.
- The `ultraswarm` depth of the kit already held such a second copy of the flags. Reviewers reported it as a problem, and 15 of the 40 problems found belonged to that depth (@.archcore/research/polybrief-review-findings.doc.md).

The project stack rule (@../ivklgn-kit/.archcore/conventions/project-stack.rule.md) allows Markdown and Bash, and asks for an ADR before another framework comes in.

## Decision

Swarm patterns run on a runner of the kit's own, written in Bash, that walks a pattern file.

- A pattern is one Markdown file in `patterns/`. Its format is in @.archcore/runtime/polybrief-pattern-file.spec.md.
- The runner is `scripts/swarm_pattern.sh`. Its contract is in @.archcore/runtime/polybrief-pattern-runner.spec.md.
- The runner starts workers only through the launcher. The CLI names and the isolation flags stay in one place.
- Taken from crewplane: stages in one file, participants per stage, one prompt section per stage, earlier answers inserted by a placeholder.
- Taken from taskflow: a contract that an answer has to meet, with a retry, and a gate that calls no model.
- The host stays the judge. A verdict of a worker and a result of a gate are data for the judge, not the verdict of the review.
- The `ultraswarm` depth is removed. Its decision record is rejected (@.archcore/architecture/ultraswarm-optional-engine.adr.md).
- The launcher is hardened before the runner is built; the order is in @.archcore/runtime/polybrief-pattern-runner.plan.md.

## Alternatives

- crewplane as the pattern engine. It ran the cross-check pattern at the first attempt, in 639 seconds. Rejected: it needs Python 3.13, has no safe defaults, needed three workarounds, holds a copy of the flags, and has no condition and no gate for parallel nodes.
- taskflow as the pattern engine. It has the richest language and the full set of isolation flags. Rejected: it is a beta, has no command that runs a flow, and runs one vendor per flow; the test needed a driver and a router written for it.
- Workflow scripts of Claude Code. A script holds loops and conditions. Rejected: a step is always a Claude subagent, the script cannot run a command, and it works in Claude Code only.
- Patterns as Markdown that the host model follows, with no runner. It needs no code. Rejected for running: two runs of one pattern differ, every round passes through the host's context, and a terminal cannot run it.
- counselors, consilium, consult-llm and touchstone. Rejected: each has a fixed topology, or its patterns need a host model.
- Keeping the `ultraswarm` depth next to the runner. Rejected: its review stage is not isolated, and it reviews commits only.

## Consequences

- The kit gets new code to keep: a runner of about 150 to 250 lines and its self-check.
- The format is the kit's own. It has no documentation outside this repository.
- Workers keep no session, so every stage sends the change again. The cost grows with stages times participants.
- Conditions are regular expressions on the lines of an answer, not a language. A pattern that needs more does not fit.
- One file holds the safety flags. A new worker is added in the launcher, and every pattern can use it.
- The evidence supports parallel review and one refutation round with a fixed verdict format. Other patterns are experiments, and the plan measures them before they become defaults.
- A run with the depth `ultraswarm` is no longer possible. A review of uncommitted work was never possible with it.


## Migration note

Imported from `ivklgn-kit/.archcore/codereview/swarm-pattern-runner.adr.md`. Historical experiments and verdicts are unchanged; see the Provenance section of `.archcore/architecture/standalone-runtime.adr.md`. The standalone interface adds optional Git context and caller-owned checklists; the extraction ADR defines that change.
