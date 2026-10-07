# polybrief: details

The short introduction is in the [README](../README.md). This page keeps the full
command line, the settings, the safety limits, and the checks.

## Install

Needs a configured CLI for each selected worker (`codex`, `claude`, or `opencode`).
Git is needed only for review mode. A worker using an API provider may need a key;
a CLI using a subscription login may not. The binary embeds its built-in patterns.

The install scripts download the release archive for your system, check it against
`checksums.txt` (SHA-256), and put the binary in place:

- [`install.sh`](../install.sh) (macOS, Linux): `~/.local/bin/polybrief`. It prints a hint
  when that directory is not on `PATH`; it does not edit your shell files.
- [`install.ps1`](../install.ps1) (Windows): `%LOCALAPPDATA%\Programs\polybrief\polybrief.exe`,
  and it adds that directory to your user `PATH`.

Both read `POLYBRIEF_VERSION` (for example `v0.2.0`; default: latest release) and
`POLYBRIEF_INSTALL_DIR`. Run the same command again to update.

Manual install: download `polybrief_<os>_<arch>.tar.gz` (`linux`, `darwin`) or
`polybrief_windows_<arch>.zip` from [Releases](https://github.com/ivklgn/polybrief/releases/latest),
where `<arch>` is `amd64` or `arm64`, and put the binary in any directory on `PATH`.

Windows support is experimental: the read-only isolation of the workers has been
checked on macOS and Linux only. The binaries are not signed, so macOS may block a
file downloaded with a browser (`xattr -d com.apple.quarantine polybrief`) and Windows
SmartScreen may warn on first start.

With Go 1.25 or newer: `go install github.com/ivklgn/polybrief@latest`.

## Usage

```
polybrief [-C DIR] [-b REF] [-p PATTERN] [-c FILE]... [-w LIST] [-o KEY=VALUE]... [--label TEXT] [--config FILE] BRIEF|-
polybrief plan   [-p PATTERN] [-c FILE]... [-w LIST] [-o KEY=VALUE]...
polybrief patterns [--config FILE]
polybrief config [-o KEY=VALUE]...
polybrief yield  [--label TEXT] RUN NAME=RAISED/KEPT/ONLY...
```

```bash
polybrief -C ~/proj task.md                                     # default: independent answers
polybrief -C ~/proj -p crosscheck examples/research/brief.md   # staged cross-check
polybrief -C ~/repo -b main examples/code-review/brief.md      # add a Git change as context
polybrief -C ~/repo -b main -p twice - < review.md             # two answers from each client
polybrief -w claude -o claude.effort=max question.md           # one client, one override
polybrief -w opencode -o opencode.model=openai/gpt-5 question.md # OpenCode only
polybrief plan -p panel -c review-security.md -c review-tests.md
```

The [examples](../examples/README.md) show research, code review and OpenCode with the current
read-only profile. A pattern can also describe other analysis tasks.

With `-b`, the change is base to working tree, including untracked files; secret-like
names are left out, and Git history is added. A stage that inserts the brief then
expects `FINDING`, `NOT-CHECKED`, or `NO FINDINGS`; without `-b`, any non-empty answer
counts. Built-in patterns ([guide](patterns.md)): `parallel` (default), `twice`, `panel`, `crosscheck`; the
former `refute` is in `examples/refute/`. Checklists stay caller-owned (`-c FILE`);
a pattern names a checklist by its file name without `.md`.

A review run prepares one Git change for all participants and stages. Polybrief copies the
brief and selected checklists into `OUT`, then checks the selected Git inputs for
persistent changes during the run. The final `RESULT` line is `complete`, `partial`,
`stale`, or `failed`. A `partial` run can exit 0 when each stage still has an `ok`
answer; a `stale` run exits 1. The caller still checks each finding against the code.

Host agents call `polybrief` as a shell command. A run takes minutes, so run it in the
background; the first line `OUT <dir>` names the directory that keeps every prompt
and answer.

## Configure

```ini
# ~/.config/polybrief/polybrief.conf — every line is optional
[codex]
model  = gpt-6-sol
effort = medium

[claude]
effort = high

[opencode]
model = openai/gpt-5
variant = high
web = off
```

`polybrief config` prints each setting, its value and its source. Order: default <
settings file < `-o`. Codex model and effort fall back to the top level of
`~/.codex/config.toml`. The 0.1.0 dotted form (`codex.model = ...`) still works.
`polybrief patterns` lists embedded and user patterns. Run-level `--label` identifies
worker calls in the log; `-o expect=REGEX` is available for a caller's one-off
answer contract, while an `expect` line in the settings file is ignored.
Config: `--config`, else `POLYBRIEF_CONFIG`, else `${XDG_CONFIG_HOME:-~/.config}/polybrief/polybrief.conf`.
User patterns: `~/.config/polybrief/patterns/*.md` (or `POLYBRIEF_PATTERNS_DIR`).
Log: `${XDG_STATE_HOME:-~/.local/state}/polybrief/polybrief-runs.tsv`.
User config, user patterns, and temporary output must be outside the target tree.
OpenCode is optional and is not in the default worker list. Use `-w opencode` or
name it in a custom pattern. In a stage without `run:` lines (`parallel`, `crosscheck`),
`-w` names the workers; in a stage with `run:` lines (`twice`, `panel`), it only
removes participants.
Its `model` is required when OpenCode runs and uses `provider/model`, so a run always
names the model that answered; `variant` is the
provider-specific reasoning level. A stored `opencode auth login` is linked into the
worker's private data area; OpenCode refreshes an OAuth token in place, so a refresh
updates your `auth.json`. Without a stored login, pass a provider key by name, for
example `-o env=OPENAI_API_KEY`. Of the `OPENCODE_*` and `XDG_*` names in `env`, only
`OPENCODE_API_KEY`, `OPENCODE_ENABLE_EXA`, and `OPENCODE_ENABLE_PARALLEL` reach the
worker; the others would change its profile and are dropped (a direct `polybrief launch`
call names them on stderr; a pattern run does not show that note). Polybrief gives
OpenCode a private HOME and XDG data area, disables project config and external
plugins, and allows only read/search tools by default. The `read` tool refuses `.env`
files, but `grep` still searches a `.env` file that is not gitignored.
`opencode.web=on` also permits webfetch, and websearch where OpenCode offers it.
This is a CLI permission profile, not an OS filesystem sandbox. OpenCode managed
configuration may override it. The profile was checked with OpenCode 1.18.34
against its [CLI](https://opencode.ai/docs/cli/),
[permissions](https://opencode.ai/docs/permissions/), and
[configuration](https://opencode.ai/docs/config/) documentation. No answer from a real
provider has been recorded yet, so treat the OpenCode worker as experimental.
Secret-name filtering applies to generated diffs; it is not a filesystem access
policy for the workers and does not scrub a caller-supplied brief or checklist.
Skipped file names appear in local `SKIPPED` lines; the generated omission notice
gives workers only a count. Commit subjects and caller-supplied text are not scrubbed.
Automatically added history is capped at 16,000 bytes; a truncated diff lists
at most 100 changed paths and 16,000 path bytes. `OMITTED` reports any further
history lines or paths locally. Workers can still read files available to the OS
account, and a file changed and restored during one worker call can escape drift
detection. Drift checks also exclude the contents of skipped secret-like files and
ignored files.
Each worker call is a full agent session that spends subscription limits; `polybrief plan`
shows the highest call count before a run. The settings file is read again for each
worker call, so keep it unchanged while comparing runs. Shell login files (`.zprofile`
and similar) can still set variables inside the `codex` worker's commands.

See [the settings example](../polybrief.conf.example), [the worked examples](../examples/README.md),
and the [pattern reference](../.archcore/runtime/polybrief-reference.doc.md).

## Checks

```bash
go test ./...
bash tests/test_review.sh
bash tests/test_pattern.sh
bash tests/test_cli.sh
```

The shell checks build the binary (or take `POLYBRIEF_BIN`) and use fake workers. They do
not call a model. Read-only flags, timeouts, partial answers, malformed output,
environment filtering, diff collection, stage routing, retries, gates, limits, and the
public command line are covered.
With OpenCode installed, `POLYBRIEF_TEST_REAL_OPENCODE=1 go test -run TestInstalledOpenCodeProfile ./...`
checks its effective configuration without a model call. Run it after each OpenCode
update: polybrief records the OpenCode version but does not re-check the profile at run time.

## Research and provenance

The engine, tests, presets, and nine Archcore documents were extracted from
`ivklgn-kit`. The historical investigations and measurements are in
[`.archcore/research/`](../.archcore/research/), current contracts in
[`.archcore/runtime/`](../.archcore/runtime/), and decisions in
[`.archcore/architecture/`](../.archcore/architecture/).
The [extraction decision](../.archcore/architecture/standalone-runtime.adr.md) maps the
original paths and the source revision. Historical verdicts do not imply a current
retest of other tools.
