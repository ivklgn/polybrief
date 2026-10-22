Refine the backlog item below against this repository as it is today. The item is a
request from the product side, written before anyone looked at the code. Do not
implement it. The goal is a refined item: what is already there, what is real work,
what the item contradicts, what it would break, and what has to be asked before work.

## The item

<item>
Let users keep their defaults. Add a settings file at
`~/.config/polybrief/config.toml` that holds `opencode.model`, `workers` and
`timeout`, read before the `-o` arguments. Also let people preview a pattern:
`polybrief plan` should show the stages and the call count before a run, and
there should be a way to list the built-in patterns.
</item>

## Scope

The command line and its settings: `main.go`, `config.go`, the specs and decisions
under `.archcore/runtime/` and `.archcore/architecture/`, and `tests/test_cli.sh`.
