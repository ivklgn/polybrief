# Research: Claude + Codex

This [skill folder](SKILL.md) uses Polybrief's embedded **`crosscheck` pattern**.
Claude and Codex first investigate the same question independently. Then each
reads and critiques the other's answer. That yields two analyses and two
critiques; the caller checks the cited evidence and writes the conclusion.

Install Polybrief and sign in to the Claude Code and Codex CLIs. The supplied
[brief](references/brief.md) investigates a concrete design question in the Polybrief
repository, so this command is ready to try from its checkout:

```bash
polybrief -C "$(pwd)" -p crosscheck -w claude,codex \
  --label research "$(pwd)/examples/research/references/brief.md"
```

To research your own question, write a brief and pass its absolute path:

```bash
polybrief -C /path/to/project -p crosscheck -w claude,codex \
  --label research /path/to/my-question.md
```

Use `-` as the final argument to supply the brief on stdin. The
[skill](SKILL.md) describes how to make a useful brief from a user question and
calls Polybrief directly.
Copy the whole folder to `~/.codex/skills/polybrief-research/` or
`~/.claude/skills/polybrief-research/` if you want an agent to run and
synthesize it. See [references/research-results.md](references/research-results.md) for the four output files and
the evidence-checking method. A call-free plan is
`polybrief plan -p crosscheck -w claude,codex`.
