# Code review: Codex + OpenCode

This is a copyable [skill folder](SKILL.md). It uses Polybrief's embedded
**`parallel` pattern**: Codex and OpenCode review the same Git change
independently. The skill then verifies their findings against the code and
reports a final review. The [brief](references/brief.md) and [reference](references/review-results.md)
stay with the skill.

Install Polybrief and sign in to the Codex and OpenCode CLIs. OpenCode also
needs a model in `provider/model` form. From this folder, review a branch:

```bash
repo=/path/to/repo
model=provider/model
base="$(git -C "$repo" merge-base HEAD origin/main)"
polybrief -C "$repo" -b "$base" -p parallel -w codex,opencode \
  -o "opencode.model=$model" --label code-review "$PWD/references/brief.md"
```

Replace `origin/main` with the branch you are reviewing against and
`provider/model` with an available OpenCode model. If invoking the skill from
another directory, use the absolute path to `references/brief.md`. For a dry plan
without model calls:

```bash
polybrief plan -p parallel -w codex,opencode
```

To install it as an agent skill, copy the **whole folder** into your agent's
skills directory, for example `~/.codex/skills/polybrief-code-review/` or
`~/.claude/skills/polybrief-code-review/`. The skill finds the merge base,
runs Polybrief directly, reads both answers, and verifies each finding before
reporting it. See [references/review-results.md](references/review-results.md) for statuses and
customization. The optional [security](references/review-security.md) and
[test](references/review-tests.md) checklists are for `panel`; the main skill does not need them.

## Try the other review patterns

The skill above stays on `parallel`. To try the same brief with the other
built-in review patterns, sign in to the Codex and Claude CLIs, then run these
commands from this folder. Reuse `repo` and `base` from the first command.

**`twice`** runs two independent Codex reviews and two independent Claude
reviews. It makes four calls; its participants are fixed in the pattern.

```bash
polybrief -C "$repo" -b "$base" -p twice \
  --label code-review-twice "$PWD/references/brief.md"
```

**`panel`** asks Codex to focus on security and tests, and Claude on design.
It needs the two supplied checklists. It makes two calls, or up to four if an
answer has the wrong format and is retried.

```bash
polybrief -C "$repo" -b "$base" -p panel \
  -c "$PWD/references/review-security.md" \
  -c "$PWD/references/review-tests.md" \
  --label code-review-panel "$PWD/references/brief.md"
```

Preview either run without calling a model:

```bash
polybrief plan -p twice
polybrief plan -p panel \
  -c "$PWD/references/review-security.md" \
  -c "$PWD/references/review-tests.md"
```

Read the `WORKER` lines for the answer paths: `twice` names `codex-1`,
`codex-2`, `claude-1`, `claude-2`; `panel` names `risk` and `design`. Verify
findings against the code as in the main skill.
