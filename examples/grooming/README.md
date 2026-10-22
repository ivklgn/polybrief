# Grooming

A skill for backlog refinement: take one item before work and find out what
is already in the code, what is real work, what the item contradicts, what it
would break and what has to be asked. Codex and Claude each read the item and
the code and report rows: `ALREADY`, `GAP`, `CONFLICT`, `BREAKS`, `UNCLEAR`.
The skill verifies the rows and writes the refined item: acceptance criteria,
out of scope, decisions needed, risks, open questions. It runs Polybrief
with the pattern file `grooming.md` from this folder, two model calls, up to
four with retries.

## From your agent

Copy this folder to `~/.claude/skills/grooming/` or `~/.codex/skills/grooming/`,
then:

```text
/grooming PROJ-150                              a ticket key, fetched with your tracker tool or pasted
/grooming add CSV export to the report page in internal/report
/grooming /tmp/item.md                          the item from a file
```

## By hand

The sample item asks this repository for a settings file and a pattern
preview. One part contradicts an accepted decision record, one already exists.
Polybrief refuses a pattern file inside the repository it looks at, so copy
the pattern out first:

```bash
pattern="$(mktemp -d)/grooming.md"
cp grooming.md "$pattern"
polybrief -C "$(git rev-parse --show-toplevel)" -p "$pattern" -w codex,claude \
  --label grooming "$PWD/references/brief.md"
```

Your own item: copy `references/brief.md`, replace its `## The item` and
`## Scope` sections, and point `-C` at the repository. When this folder lies
outside that repository, `grooming.md` can be used in place:

```bash
polybrief -C /path/to/repo -p "$PWD/grooming.md" -w codex,claude \
  --label grooming /tmp/item.md
```

Preview without a model: `polybrief plan -p "$PWD/grooming.md"`.

Row meanings, measured limits and how to adapt the brief:
[references/grooming-results.md](references/grooming-results.md).
