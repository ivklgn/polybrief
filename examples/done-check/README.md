# Done check

A skill that answers one question before a task is closed: does the change do
what the task asked? The task text is the definition of done. Codex and Claude
each compare it with the diff and report rows: `CONFLICT`, `MISSING`, `EXTRA`,
`UNCLEAR`, `MATCH`. The skill verifies each mismatch and reports it. It runs
Polybrief with the `intent` pattern, two model calls.

## From your agent

Copy this folder to `~/.claude/skills/done-check/` or
`~/.codex/skills/done-check/`, then:

```text
/done-check PROJ-142                            a ticket key, fetched with your tracker tool or pasted
/done-check origin/develop                      a base first, then paste the ticket text
/done-check /tmp/task.md                        the task from a file
```

The skill writes the task to a file outside the repository, finds the merge
base, runs Polybrief, checks every `CONFLICT` and `MISSING` row against the
task and the code, and reports what is missing, conflicting or extra. It never
writes the task from the diff.

## By hand

The sample task is the one behind commit `bf5e8fb` of this repository. Run it
in a throwaway worktree:

```bash
repo="$(mktemp -d)/polybrief-done-check"
git worktree add --detach "$repo" bf5e8fb
polybrief -C "$repo" -b 165ddf8 -p intent -w codex,claude \
  -c "$PWD/references/task.md" --label done-check "$PWD/references/brief.md"
git worktree remove "$repo"
```

Your own change: the task in a file outside the repository, the merge base as
`-b`, and `-c /tmp/spec.md` when the change also updates a specification:

```bash
polybrief -C /path/to/repo -b "$(git -C /path/to/repo merge-base HEAD origin/main)" \
  -p intent -c /tmp/task.md --label done-check "$PWD/references/brief.md"
```

Preview without a model: `polybrief plan -p intent -w codex,claude`.

Row meanings, measured limits and how to adapt the brief:
[references/done-check-results.md](references/done-check-results.md).
