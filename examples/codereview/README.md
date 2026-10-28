# Code review

A skill that reviews a Git change before merge. Codex and OpenCode each review
the change on their own. The skill checks every finding against the code and
reports the ones that hold. It runs Polybrief with the `parallel` pattern,
two model calls.

## From your agent

Copy this folder to `~/.claude/skills/codereview/` or
`~/.codex/skills/codereview/`, then:

```text
/codereview                                   current branch against the default branch
/codereview origin/develop                    against another base
/codereview main check the migration rollback a base plus a focus for the reviewers
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
  -o opencode.model=provider/model --label codereview "$PWD/references/brief.md"
```

Preview without a model: `polybrief plan -p parallel -w codex,opencode`.

## More samples

Needs the Codex and Claude CLIs. `twice` runs four reviews, two per worker,
and is the one to pick when one run is not enough: in the measured runs a
second sample found problems the first missed (`.archcore/research/polybrief-measured-runs.rnd.md`,
Finding 3).

```bash
polybrief -C "$repo" -b "$base" -p twice --label codereview-twice "$PWD/references/brief.md"
```

## Role-based review

The caller-owned [panel.md](panel.md) example gives Codex the security and test
checklists and Claude the design lens. The measured runs did not establish a
quality gain over `parallel`. Use it to try role and checklist selection.
Keep the copied skill folder outside the repository being reviewed: Polybrief
refuses a custom pattern inside its target directory. Set `skill_dir` to the
absolute path of that copied folder:

```bash
polybrief -C "$repo" -b "$base" -p "$skill_dir/panel.md" \
  -c "$skill_dir/references/review-security.md" \
  -c "$skill_dir/references/review-tests.md" --label codereview-panel "$skill_dir/references/brief.md"
```

Statuses, output paths and how to adapt the brief: [references/review-results.md](references/review-results.md).
