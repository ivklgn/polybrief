# OpenCode example

OpenCode is an optional worker. It is not in the default pair, so you select it
with `-w`. With the `parallel` pattern, `-w` names the workers that answer.
[polybrief.conf](polybrief.conf) sets the OpenCode model, which is required, in
`provider/model` form.

From the repository checkout, OpenCode alone:

```bash
polybrief -C /path/to/repo -b main -w opencode --config examples/opencode/polybrief.conf examples/code-review/brief.md
```

Three independent reviewers on three models:

```bash
polybrief -C /path/to/repo -b main -w codex,claude,opencode --config examples/opencode/polybrief.conf examples/code-review/brief.md
```

The same works for `crosscheck`: `-p crosscheck -w claude,opencode` makes Claude
and OpenCode check each other. In a pattern with explicit `run:` lines, such as
`twice` or `panel`, `-w` only removes participants. To add OpenCode there,
copy the pattern and add a `run: opencode` line.

Without a stored `opencode auth login`, pass the provider key by name, for
example `-o env=OPENAI_API_KEY`. The OpenCode worker is experimental; see
[details](../../docs/details.md#configure) for its read-only profile and limits.
