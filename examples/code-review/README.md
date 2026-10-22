# Code review

A skill that reviews a Git change before merge. Codex and OpenCode each review
the change on their own. The skill checks every finding against the code and
reports the ones that hold. It runs Polybrief with the `parallel` pattern,
two model calls.

## From your agent

Copy this folder to `~/.claude/skills/code-review/` or
`~/.codex/skills/code-review/`, then:

```text
/code-review                                   current branch against the default branch
/code-review origin/develop                    against another base
/code-review main check the migration rollback a base plus a focus for the reviewers
```

The skill finds the merge base, picks the OpenCode model from `polybrief
config` or asks for one, runs Polybrief, and reports confirmed findings with
`file:line`, impact and evidence. Rejected claims and unchecked concerns are
listed apart.

## By hand

```bash
repo=/path/to/repo
base="$(git -C "$repo" merge-base HEAD origin/main)"
polybrief -C "$repo" -b "$base" -p parallel -w codex,opencode \
  -o opencode.model=provider/model --label code-review "$PWD/references/brief.md"
```

Preview without a model: `polybrief plan -p parallel -w codex,opencode`.

## More samples

Needs the Codex and Claude CLIs. `twice` runs four reviews, two per worker,
and is the one to pick when one run is not enough: in the measured runs a
second sample found problems the first missed (`.archcore/research/polybrief-measured-runs.rnd.md`,
Finding 3). `panel` gives Codex the security and test checklists and Claude
the design lens. It found the same problems as `parallel` (Finding 4) and is
here to show how checklists reach one worker.

```bash
polybrief -C "$repo" -b "$base" -p twice --label code-review-twice "$PWD/references/brief.md"
polybrief -C "$repo" -b "$base" -p panel -c "$PWD/references/review-security.md" \
  -c "$PWD/references/review-tests.md" --label code-review-panel "$PWD/references/brief.md"
```

Statuses, output paths and how to adapt the brief: [references/review-results.md](references/review-results.md).
