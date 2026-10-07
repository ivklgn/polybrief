# Examples

Each example has its own directory. They show uses of the current read-only
worker profile, not a fixed list of task types.

Each directory has its own `polybrief.conf` for its workers. The brief
describes the task, the pattern describes its stages, and the config controls
the workers' models, effort, web access and timeout. Each command passes its
config with `--config`; use `polybrief config --config FILE` to inspect it.

For normal use, settings can live at `~/.config/polybrief/polybrief.conf` instead. When
unset, Codex's model and effort each come from the top level of
`~/.codex/config.toml`; Claude Code uses its CLI defaults. Use `-w codex` to run
only Codex, or `-o codex.effort=high` to change one setting for one run. The
[full settings template](../polybrief.conf.example) lists the other keys. Keep a
settings file outside the directory passed with `-C`.

- [Research](research/README.md): compare approaches, then cross-check answers with `crosscheck`.
- [Code review](code-review/README.md): review a Git change with independent workers,
  and a Claude Code skill that runs it and checks the findings.
- [OpenCode](opencode/README.md): add OpenCode as a third worker, or run it alone.
- [Refute](refute/README.md): an optional pattern that checks another reviewer's findings.

Commands in these examples assume the current directory is this repository
checkout. After installing the binary, a brief or pattern file can be supplied
from any location.
