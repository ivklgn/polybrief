---
title: "The ultraswarm depth calls ultraswarm directly"
status: rejected
tags:
  - "codereview"
---

Rejected on 2026-09-29. The `ultraswarm` depth was built, run and then removed; its files are no longer in the repository. The decision that replaces it is @.archcore/architecture/polybrief-pattern-runner.adr.md. Reasons: the review stage of ultraswarm starts `claude -p` with no tool or settings limit, the depth reviews commits only, its settings held a second copy of the isolation flags, and 15 of the 40 problems found by the test runs belonged to it (@.archcore/research/polybrief-review-findings.doc.md). The text below is kept as the record of what was decided on 2026-09-27.

## Context

The swarm review of `/codereview` started with one way to run the workers: a Bash launcher that starts `codex` and `claude` itself (@scripts/swarm_review.sh). The research behind it (@.archcore/research/polybrief-review-engine.rnd.md) recommended that launcher, because ultraswarm has no read-only review mode.

On 2026-09-27 the user asked to keep that swarm and to build the same scenario on ultraswarm, in order to try ultraswarm on a real task. A first version put ultraswarm behind the launcher, inside a throwaway clone and with its review stage switched off. The user then asked for ultraswarm without a script in between: in that version ultraswarm did little more than start processes.

The project stack rule (@../ivklgn-kit/.archcore/conventions/project-stack.rule.md) allows Markdown and Bash, and asks for an ADR before another framework comes in. ultraswarm is a Node tool.

## Decision

The depth `ultraswarm` of `/codereview` calls ultraswarm directly, with the commands written in `skills/codereview/references/ultraswarm.md` (removed). No script of the kit wraps it.

- The depth `swarm` and its launcher stay as they are. Nothing in the kit needs ultraswarm or Node unless the depth `ultraswarm` is asked for.
- The settings are two static files next to the reference: `ultraswarm.config.json` (workers, model, time limit) and `ultraswarm.plan.json` (one task per worker).
- The skill makes a worktree for the run outside the project and commits the review input to it: the brief, the change and the checklists, as files.
- ultraswarm runs with its own review stage on. The host still verifies every finding and gives the verdict.
- The workers stay read-only. The command in the config saves a worker's final message into the findings file.
- Root lockfiles are removed from the run worktree, so ultraswarm installs nothing.
- The skill never runs `ultraswarm merge`, and removes the run worktree and the `ultraswarm/*` branches after the run.

## Alternatives

- ultraswarm behind the launcher, in a throwaway clone, with its review stage off. Built and checked first, then removed at the user's request. It covered uncommitted work and left the repository untouched during the run; it used almost nothing of ultraswarm and added about 150 lines of Bash and inline JavaScript.
- Workers with write access, which write the findings file themselves. Rejected: the kit's reviewers are read-only by enforcement, and a command in the config reaches the same result.
- The plan written by the host model for each run. Rejected: a model writing long JSON strings by hand is a source of errors; a static plan and input in files need no JSON from the model.
- A shell limited to `git diff`, `git log` and `git show` for the Claude worker, so that it reads the change itself. Checked and rejected: `git diff --output=<file>` writes a file.

## Consequences

- The `ultraswarm` depth reviews commits only. Uncommitted and untracked work stays out; `swarm` covers it.
- During a run the user's repository holds one more worktree and the branch `ultraswarm/run-<ID>`. After a crash they stay until the clean-up commands are run by hand.
- The depth has no automated check: it is a list of commands that a model follows. It was followed by hand once, on a test project, on 2026-09-27.
- The review stage of ultraswarm adds Claude calls and can reject an attempt; ultraswarm does not record the reason. In the hand check one attempt of three was rejected, and the run took 426 seconds against 128 seconds without a rejection.
- The commands of the depth are not pre-approved in the skill, so the host asks the user before it makes the worktree and before it starts ultraswarm.
- An update of ultraswarm can break the depth: the config keys, the plan format and the fields of `status` are not a public contract. It was checked at commit `fe11309` (version 3.6.1).
- The Codex model is named in the config file. When the user changes the model in `config.toml`, the file has to follow.

## Migration note

Imported from `ivklgn-kit/.archcore/codereview/ultraswarm-optional-engine.adr.md`. Historical experiments and verdicts are unchanged; see the Provenance section of `.archcore/architecture/standalone-runtime.adr.md`. The standalone interface adds optional Git context and caller-owned checklists; the extraction ADR defines that change.
