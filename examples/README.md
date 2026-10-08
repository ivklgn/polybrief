# Examples

The two full examples are folders you can copy into an agent's skills directory.
They use the current read-only worker profile. A brief states the task;
a built-in pattern states the order of agent calls.

| Folder | Pattern | Workers | Result |
| --- | --- | --- | --- |
| [Code review](code-review/README.md) | `parallel` | Codex + OpenCode | Two independent reviews; the skill checks findings against the code. |
| [Research](research/README.md) | `crosscheck` | Claude + Codex | Two analyses and two critiques; the skill checks sources and synthesizes the answer. |

The code review folder also has runnable `twice` and `panel` variants for the
same brief. Its skill keeps `parallel` as the default workflow.

This repository exposes both folders as Claude Code project skills through
`.claude/skills/`. In Claude Code opened here, invoke `/polybrief-code-review`
or `/polybrief-research`.

Each folder contains `SKILL.md` and a `references/` directory with its sample
`brief.md` and result-checking guide. The skill gives the main agent the Polybrief
command and tells it how to check the answers. The selected agent CLIs and
Polybrief must be on `PATH`; OpenCode also requires an available model name.

Polybrief does not search `references/` by itself. The code review skill passes
its brief path explicitly; the optional `panel` command also passes both
checklist paths with `-c`. The research skill creates a brief from your question
or uses one you supply; its `references/brief.md` is a runnable sample.

For a pattern written from scratch, see the command reference in the repository:
`.archcore/runtime/polybrief-reference.doc.md`, section "Custom pattern from scratch"
(that link does not travel with a copied folder).
