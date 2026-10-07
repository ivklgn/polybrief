# Code review example

[brief.md](brief.md) asks for actionable findings. `-b` adds the Git change
from the chosen base to the working tree, including untracked files. The
default `parallel` pattern sends the same brief and change to independent
workers. [polybrief.conf](polybrief.conf) configures both workers.

From the repository checkout:

```bash
polybrief -C /path/to/repo -b main --config examples/code-review/polybrief.conf examples/code-review/brief.md
```

The caller checks each finding against the code before acting on it. For a
longer workflow, use a different pattern with the same brief.

## From a code review skill

[SKILL.md](SKILL.md) is a small Claude Code skill built on this example. Copy it to
`~/.claude/skills/second-opinion-review/SKILL.md`. It runs polybrief in the
background on the current branch, reads each answer from the `OUT` folder, and
checks every finding against the code before it reports it. polybrief gives the
second opinion; the skill stays the judge.

If your review skill already has reviewer instructions, pass them to the `panel`
pattern as checklists. `panel` gives Codex the files named `review-security` and
`review-tests`, and Claude a design lens:

```bash
polybrief -b main -p panel -c path/to/review-security.md -c path/to/review-tests.md examples/code-review/brief.md
```

Run `polybrief plan -p panel -c ... -c ...` first to see how many agent calls the run can spend.
