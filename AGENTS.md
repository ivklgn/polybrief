# Polybrief

Reply in the user's language. Base claims on code, test output, or cited sources.

## Scope

This is a standalone pattern runtime for local agent CLIs, built as one Go binary.
The current worker profile is read-only. Research and code review are initial
examples, not the limit of the project. Describe a write-capable workflow as a
future capability until its execution and isolation contract exists.
Keep worker startup and isolation flags in `launch.go` and its per-OS files
(`launch_unix.go`, `launch_windows.go`), and configuration parsing in `config.go`. The pattern runner (`runner.go`) must start workers only through the launcher.
In the current runtime, callers own task briefs, checklist files, evidence
verification, and final decisions.
Do not add a dependency on ivklgn-kit or embed its reviewer checklists.

## Stack and checks

Go (standard library only, no `require` in `go.mod`) and Markdown. No provider SDK,
server, or database. Run `go test ./...`, `bash tests/test_review.sh`,
`bash tests/test_pattern.sh`, and `bash tests/test_cli.sh`. The shell checks build
the binary (or use `POLYBRIEF_BIN`), use fake workers, and spend no model quota.
Releases: a `vX.Y.Z` tag runs `.github/workflows/release.yml` (GoReleaser, CI only);
see `.archcore/runtime/polybrief-release.guide.md`.

## Project context

Search `.archcore/` before changing behavior. Runtime specs live in
`.archcore/runtime/`; imported investigations live in `.archcore/research/`.
Record decisions and update the affected contracts. Imported measurements describe
historical runs in ivklgn-kit, not validation of a newer third-party release.
The project was named `swarm` before 2026-10-04; records of past work keep that
name (`.archcore/architecture/polybrief-rename.adr.md`).

<!-- archcore:start --> managed by `archcore init` — edit outside these markers
## Archcore — project context for this repo

This repo's architecture, decisions, rules, specs and patterns live in `.archcore/`,
reachable through the Archcore MCP tools. Consult them even on code you think you
know — a decision or rule may already constrain it.

- Touching this repo's real code or behavior → search first; read only what matches.
- A decision was made ("we'll use X", "from now on Y") → record it.
- A module / API / system has no doc — or a search comes back empty → capture it.
- Planning a feature or refactor → scope it against what's already decided.

A `.archcore/` may also mount read-only **global sources** — shared, org-wide
context not shown in the session-start list. `list_documents` / `search_documents`
surface them alongside local docs, tagged `source_kind: "global"`. When present,
treat them as defaults a local doc can override — never edit or relate to one.

The search is cheap — lean on it. Skip it only for turns this repo would have no
opinion on: syntax trivia, throwaway snippets, pure mechanics.
<!-- archcore:end -->
