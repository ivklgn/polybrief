# polybrief: patterns

A pattern says which agents answer the brief and in which order. This page explains
each built-in pattern: how it works, what it gives you, and which tasks it fits.
The short overview with diagrams is in the [README](../README.md#patterns-how-the-agents-work-together).

All patterns are read-only. polybrief does not judge the answers: you (or your main
agent) check each claim against the code. Before a run, `polybrief plan -p NAME` shows
the stages and the maximum number of agent calls.

## How to choose

| Your task | Pattern |
| --- | --- |
| A second opinion on a change or a question, at the lowest cost | `parallel` |
| A review where a missed problem costs more than extra calls | `twice` |
| A question with no single right answer: design choice, trade-offs, investigation | `crosscheck` |
| A review where you already have checklists for security, tests and design | `panel` |

The numbers below come from measured runs on real changes (see
[Where the numbers come from](#where-the-numbers-come-from)). They are rough:
few changes, few runs, and the judge was also a model.

## `parallel` (default)

**How it works.** One stage. Each agent gets the same prompt: the brief, the
checklists from `-c`, and with `-b` the Git change and recent history. The agents
do not see each other's answers. One call per agent: 2 by default, 3 with
`-w codex,claude,opencode`. With `-b`, each answer must start with `FINDING`,
`NOT-CHECKED` or `NO FINDINGS`.

**What it gives.** Two models with different strengths look at the same thing.
In the measured runs Codex and Claude each found problems the other missed: of 30
real problems, Codex alone found 5 and Claude alone found 15. Codex ran the tests
in its shell and found a defect no test catches; Claude found the only major
defect in the real changes. One run found about 66% of all problems that any run
found.

**Good for:**
- a review of a branch or pull request before merge;
- a quick read-only question: "where is retry handled, and is it consistent?";
- a check of a plan or a migration script against the code.

```bash
polybrief -C ~/repo -b main examples/code-review/brief.md
polybrief -C ~/repo -w codex,claude,opencode question.md
```

**Limits.** One sample per model. Two runs of the same pattern on the same change
give different answers, so one run misses some problems.

## `twice`

**How it works.** One stage with four participants: `codex-1`, `codex-2`,
`claude-1`, `claude-2`. All four get the same prompt and work independently.
4 calls. `-w codex` keeps only the two Codex runs.

**What it gives.** More independent samples, so more of the rare problems. In
the measured runs one `parallel` run found about 66% of the problems, two runs 80%,
three runs 97%. `twice` is the same as two `parallel` runs at once. It makes twice
the calls of `parallel` and used 2.4 to 1.8 times its input tokens in the measured
runs; the time varied from run to run.

**Good for:**
- risky changes: authentication, payments, data migrations, concurrency;
- large changes, where one answer cannot cover everything;
- a final review before a release.

```bash
polybrief -C ~/repo -b main -p twice examples/code-review/brief.md
```

**Limits.** The pattern names Codex and Claude in its `run:` lines, so `-w` cannot
add OpenCode. To use OpenCode, copy `patterns/twice.md` to your patterns directory
and change those lines.

## `crosscheck`

**How it works.** Two stages.

1. `analyze`: each agent answers the brief and states its conclusion, evidence,
   assumptions and open questions.
2. `critique`: each agent gets the other agents' answers, as data, and checks
   them: which claims are supported, which are not, where the agents disagree,
   and what evidence would settle each disagreement.

Two calls per agent: 4 by default, 6 with three agents. You get all answers:
`<OUT>/analyze/1/<agent>.md` and `<OUT>/critique/1/<agent>.md`.

**What it gives.** A map of where the agents agree, where they disagree, and which
claims have no evidence. This helps when there is no test that tells a right
answer from a wrong one.

**Good for:**
- architecture choices: "a queue or a cron job for this sync?";
- comparing libraries or approaches against this codebase;
- investigations: "why are these tests flaky? Collect evidence";
- planning a migration or refactor: find wrong assumptions before you start.

```bash
polybrief -C ~/project -p crosscheck examples/research/brief.md
polybrief -C ~/project -p crosscheck -w claude,opencode question.md
```

**Limits.** `crosscheck` has not been measured yet. A similar check stage (the
former `refute` pattern, which checked the other reviewer's findings) confirmed 58
of 59 findings and removed no false finding; its value came from the extra
first-stage answers. So do not expect the check stage to filter out false
findings. For a code review, `parallel` or `twice` gives more for the same calls.

## `panel`

**How it works.** One stage, two lenses.

- Codex, role `risk`: gets the checklists `review-security` and `review-tests`, and
  looks at failure paths, security and tests.
- Claude, role `design`: gets every checklist passed with `-c`, and looks at intent,
  design, contracts, completeness and rollout.

You must pass checklist files named `review-security.md` and `review-tests.md` with
`-c`; without them the run is refused. Each answer must start with `FINDING`,
`NOT-CHECKED` or `NO FINDINGS`; an answer in another format is retried once. 2 calls,
at most 4 with retries.

**What it gives.** Each model reads your checklists in depth for its own lens,
instead of both models covering everything. In the measured runs `panel` found as
many problems as one `parallel` run (20 of 30) and was the fastest pattern
(92 s against 110 s per run). It is a choice of focus, not a way to find more.

**Good for:**
- a code review skill that already has reviewer instructions: pass them as
  checklists ([example](../examples/code-review/README.md#from-a-code-review-skill));
- teams with written security and test standards that each review must apply.

```bash
polybrief -C ~/repo -b main -p panel \
  -c review-security.md -c review-tests.md -c review-design.md \
  examples/code-review/brief.md
```

**Limits.** The lenses are fixed to Codex and Claude, like in `twice`. To change
them, copy `patterns/panel.md`.

## Your own pattern

A pattern is one Markdown file: a header with the name, the agents and the call
limit, then one section per stage. Put it in `~/.config/polybrief/patterns/` or pass
its path with `-p`. The [refute example](../examples/refute/README.md) shows a
two-stage review, and the
[pattern reference](../.archcore/runtime/polybrief-reference.doc.md) describes every setting.

## Where the numbers come from

- [Measured runs](../.archcore/research/polybrief-measured-runs.rnd.md), 2026-09-29: 5
  changes in 4 repositories, `parallel` twice, `panel` and `refute` once each. Codex
  `gpt-6-sol` (medium effort) and Claude Code on its default model.
- [Go review comparison](../.archcore/research/polybrief-go-review-comparison.rnd.md),
  2026-10-01: 2 changes, `parallel`, `twice` and `panel`.

In both, a Claude subagent judged which findings were real. OpenCode and
`crosscheck` were not part of these runs.
