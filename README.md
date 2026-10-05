# polybrief

**Ask several AI coding agents the same question. Get independent answers, side by side.**

One agent can be confidently wrong, and you will not notice. polybrief gives the same
task (a *brief*) to Codex, Claude Code, and optionally OpenCode. Each agent reads your
project on its own and answers. If you want, they then check each other's answers.
You get every answer in one folder and decide what to trust.

- **Code review** of a branch: two reviewers on different models, not one.
- **Research**: compare approaches, then let each agent challenge the other.
- **Any other read-only question** about a project: write a brief in plain text.

The agents run **read-only**: they read your code, they do not change it.

## Install

You need the agent CLIs you want to use, already logged in: `codex`, `claude`, and/or `opencode`.

```bash
# macOS or Linux
os=$(uname -s | tr A-Z a-z); arch=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
curl -fsSLO "https://github.com/ivklgn/polybrief/releases/latest/download/polybrief_${os}_${arch}.tar.gz"
tar -xzf "polybrief_${os}_${arch}.tar.gz" polybrief && mkdir -p ~/.local/bin && mv polybrief ~/.local/bin/
```

Or with Go 1.25+: `go install github.com/ivklgn/polybrief@latest`.
Windows and other options: [details](docs/details.md#install).

## Try it

Review your branch against `main`:

```bash
polybrief -C ~/my-repo -b main examples/code-review/brief.md
```

Ask a research question, with a cross-check round:

```bash
polybrief -C ~/my-project -p research examples/research/brief.md
```

A brief is just a Markdown file with the task, for example:

```text
Review the supplied Git change for correctness, security, and missing tests.
Report only actionable problems supported by the code. Do not change any file.
```

A run takes a few minutes. The first line of output, `OUT <dir>`, is the folder with every
prompt, answer, and log. The last line, `RESULT`, says `complete`, `partial`, `stale`, or `failed`.

## Patterns: how the agents work together

A pattern is a small Markdown file that says who answers and in which order.

| Pattern    | What happens                                                    |
| ---------- | --------------------------------------------------------------- |
| `parallel` | Default. Codex and Claude answer independently.                 |
| `twice`    | Each agent answers twice, independently.                        |
| `research` | Independent answers, then each agent checks the other's answer. |
| `panel`    | Review where each agent takes a different focus.                |
| `opencode` | OpenCode only.                                                  |

Choose one with `-p NAME`. Run `polybrief plan -p NAME` to see the stages and the
maximum number of agent calls before you spend any limits. You can write your own
pattern; see [`patterns/`](patterns/) and the [refute example](examples/refute/README.md).

## Good to know

- Each agent call is a full agent session. It uses your subscription limits or API key.
- Read-only mode blocks writes. It does not hide files: an agent can still read any
  file your user account can read. Details and limits per agent: [details](docs/details.md#configure).
- polybrief does not judge the answers. You (or your main agent) check each finding against the code.
- Windows support is experimental. The OpenCode worker is experimental.

## Use it from your agent

polybrief is a plain shell command, so a host agent (Claude Code, Codex, and others)
can call it. Run it in the background and read the answers from the `OUT` folder.

## More

[Full reference: flags, settings, safety limits, tests](docs/details.md) ·
[Examples](examples/README.md) ·
[Settings template](polybrief.conf.example) ·
[Design decisions](.archcore/architecture/)
