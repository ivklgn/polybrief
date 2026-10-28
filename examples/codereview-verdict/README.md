# Review verdict

A skill that reviews a Git change before merge and shows how the verdict was
reached. Codex and Claude review the change on their own. The skill checks every claim against the code
and writes a report with a section **How the reviewers decided**: who found
what and with which argument, where they disagreed, what was dropped and why,
and where the judge went against the reviewers. Every kept finding names the reviewer that raised it.
It runs Polybrief with the `parallel` pattern, two model calls, on fixed models: Codex gpt-6-sol and Claude opus, both at medium effort.

The [codereview](../codereview/README.md) skill is the cheaper sibling: two
independent reviews, two calls, and a report of confirmed findings only. Pick
this one when the reader needs to trust the verdict without reading the
workers' output, or wants to see the dispute.

## From your agent

Copy this folder to `~/.claude/skills/codereview-verdict/` or
`~/.codex/skills/codereview-verdict/`, then:

```text
/codereview-verdict                                current branch against the default branch
/codereview-verdict origin/develop                 against another base
/codereview-verdict main check the migration rollback   a base plus a focus for the reviewers
```

After the report, `challenge <number>` sends one kept finding to the reviewer
that did not raise it, to prove it wrong. One round, one more call.

## By hand

```bash
repo=/path/to/repo
base="$(git -C "$repo" merge-base HEAD origin/main)"
polybrief -C "$repo" -b "$base" -p parallel -w codex,claude --label codereview-verdict \
  -o codex.model=gpt-6-sol -o codex.effort=medium -o claude.model=opus -o claude.effort=medium \
  "$PWD/references/brief.md"
```

Preview without a model: `polybrief plan -p parallel -w codex,claude`. The report ends each finding with the reviewer that raised it, and offers `challenge <id>`: one more call to the reviewer that did not raise it.

Statuses and output paths
are the same as in the codereview
[reference](../codereview/references/review-results.md).
