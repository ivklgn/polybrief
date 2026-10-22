Make the built-in `intent` pattern a one-stage form.

Both workers get the task text, the diff and the tree after the change, and each
reports one row per item: CONFLICT, MISSING, EXTRA, UNCLEAR or MATCH, then a
SUMMARY line. The stage carries its own `expect` for these rows, so the review
answer contract (FINDING / NOT-CHECKED / NO FINDINGS) does not apply to it.
`-w` replaces the workers; the default pair stays Codex and Claude. The pattern
takes the task as `-c task.md` and an optional `-c spec.md`.

Keep `at base` in the runtime as a shipped, tested capability: the `run` clause,
the base tree and its tests stay, but no built-in pattern uses it any more.

Update what describes the pattern: the README pattern section, the patterns
document in `.archcore/`, the CLI test for `intent` and the run-at-base ADR.
