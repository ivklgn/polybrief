# Code review reference

## What runs

The skill uses the embedded `parallel` pattern: Codex and OpenCode independently
review the same brief and Git change. Neither sees the other's answer. `-b` adds
the diff from the given merge base, including uncommitted and untracked files.
The brief lives at `references/brief.md` inside the skill folder; pass its absolute path from any working directory.
OpenCode needs an explicit `provider/model`; use one your OpenCode installation can
access. The worker CLIs must be installed and authenticated.

Run `polybrief plan -p parallel -w codex,opencode` to inspect the two calls
without starting either worker.

## Reading a run

Polybrief prints `OUT`, `WORKER`, and `RESULT` lines, then every answer in full
between `<answer-…>` tags. The `WORKER` lines give the answer paths, normally
`<OUT>/review/1/codex.md` and `<OUT>/review/1/opencode.md`; the same folder
holds the prompts, and each `*.launch` file names the folder with the worker log.
`complete` means both calls produced accepted answers; it does not validate
their claims. `partial` means at least one worker failed or gave an unusable
answer (exit code stays 0). `stale` means the Git context moved during the run.
`failed` means no usable answer was produced (`stale` and `failed` exit 1).
Treat `stale` as a reason to rerun the review.

For each `FINDING`, check the cited line and the path from input to failure.
Test a concrete case when practical. Reject duplicates, pre-existing issues,
and claims without evidence. Keep `NOT-CHECKED` concerns separate from confirmed
findings. The caller owns the final decision.

## Adapting it

- Edit `references/brief.md` for your project's risk areas and desired answer format.
- Add review criteria with `-c /path/to/checklist.md` in the Polybrief call. A checklist
  adds context; it does not make the output authoritative.
- Change the two names after `-w` to use other workers. OpenCode still needs
  `-o opencode.model=provider/model` whenever it is selected.
- The [example README](../README.md#try-the-other-review-patterns) has optional
  `twice` and `panel` commands using this brief. Follow their `WORKER` lines:
  `twice` writes four named answers; `panel` writes `risk` and `design` answers.
  Both use Codex and Claude instead of this skill's Codex and OpenCode pair.
