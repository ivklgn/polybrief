# Research

A skill that answers a question about a codebase with sources. Claude and
Codex investigate on their own, then each critiques the other's answer. The
skill checks the cited evidence and writes the conclusion. It runs Polybrief
with the `crosscheck` pattern, four model calls.

## From your agent

Copy this folder to `~/.claude/skills/research/` or `~/.codex/skills/research/`,
then:

```text
/research where should retry logic live, the client or the queue worker?
/research is the cache safe under concurrent writes in internal/cache
/research /tmp/question.md                     a brief you wrote yourself
```

The skill turns the question into a brief (question, scope, criteria,
evidence to inspect), runs Polybrief, verifies the decisive claims in the
code, and reports agreement, disagreement, what the critiques exposed and
what stays unknown.

## By hand

The sample brief asks a real question about this repository, so it runs from
a checkout:

```bash
polybrief -C "$(pwd)" -p crosscheck -w claude,codex \
  --label research "$(pwd)/examples/research/references/brief.md"
```

Your own question on stdin. A quoted heredoc keeps `$` and backticks:

```bash
polybrief -C /path/to/repo -p crosscheck -w claude,codex --label research - <<'EOF'
Question: ...
Scope: ...
Evidence to inspect: ...
Report: conclusion, evidence, assumptions, unknowns.
EOF
```

Preview without a model: `polybrief plan -p crosscheck -w claude,codex`.

Output files, what the critique stage does and does not do, and a synthesis
checklist: [references/research-results.md](references/research-results.md).
