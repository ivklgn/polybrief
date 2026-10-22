# Examples

Four skills, one job each, in folders you copy into your agent's skills
directory. Polybrief runs under them. It starts two read-only worker agents
on different models and prints their answers. The skill tells your agent how
to build the brief and how to check those answers.

| Skill | Job | Call it | Runs |
| --- | --- | --- | --- |
| [code-review](code-review/README.md) | review a change before merge | `/code-review [base] [focus]` | `parallel`, Codex + OpenCode, 2 calls |
| [research](research/README.md) | answer a question about the code with sources | `/research <question> [in paths]` | `crosscheck`, Claude + Codex, 4 calls |
| [done-check](done-check/README.md) | does the change do what the task asked? | `/done-check [base] <task>` | `intent`, Codex + Claude, 2 calls |
| [grooming](grooming/README.md) | refine a backlog item before work | `/grooming <item> [in paths]` | own pattern file, Codex + Claude, 2 calls |

```text
/code-review origin/develop
/research is the cache safe under concurrent writes in internal/cache
/done-check PROJ-142
/grooming add CSV export to the report page in internal/report
```

Each folder holds `SKILL.md`, the instructions your agent follows, and
`references/` with the brief and a guide to the answers. The grooming folder
also holds its pattern file. The worker CLIs and Polybrief must be on `PATH`.
OpenCode also needs a model name. In this repository the folders are linked
from `.claude/skills/`, so Claude Code opened here has all four commands.

Which pattern, from the measured runs in `.archcore/research/`: `parallel` is
the default. `twice` adds coverage at twice the cost. `panel` found the same
problems as `parallel`. A critique stage confirmed nearly every finding it was
given. The folders say where each number comes from.
