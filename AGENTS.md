# Polybrief

Reply in the user's language. Base claims on code, test output, or cited sources.

## Scope

This is a standalone pattern runtime for local agent CLIs, built as one Go binary.
The current worker profile is read-only. Research and code review are initial
examples, not the limit of the project. Describe a write-capable workflow as a
future capability until its execution and isolation contract exists.
Keep worker startup and isolation flags in `launch.go` and its per-OS files
(`launch_unix.go`, `launch_windows.go`), and configuration parsing in `config.go`. The pattern runner (`runner.go`) must start workers only through the launcher.
The binary embeds its built-in patterns. Callers pass their briefs and optional
checklist files explicitly, and set runtime options through arguments. There is
no polybrief home or settings file. Callers own evidence verification and final
decisions.
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
Keep detailed project reference and pattern guidance in `.archcore/`; keep
`README.md` short for users and copyable skills in `examples/`.
Record decisions and update the affected contracts. Imported measurements describe
historical runs in ivklgn-kit, not validation of a newer third-party release.
The project was named `swarm` before 2026-10-04; records of past work keep that
name (`.archcore/architecture/polybrief-rename.adr.md`).

<!-- archcore:start --> managed by `archcore init`, block v2 — edit outside these markers
## Archcore — project context for this repo

`.archcore/` holds this project's recorded context as typed Markdown files,
`<slug>.<type>.md`, in three categories: knowledge (decisions, rules, contracts,
reference), vision (requirements, plans, research), and experience (lessons from
past work). `list_documents` filters by `category` and `types`.

Before you change, test, or explain code here, call `search_documents` with `for_path` set to the file, and read the rules, decisions, and specs it returns with `get_document`. Accepted rules and decisions bind the change. Without the Archcore MCP tools, read `.archcore/` as Markdown: the `*.rule.md` files first, then grep `.archcore/` for the file name.

1. Once per session, before the first code edit, call `list_documents` with
   `types: ["rule", "cpat"]` and `status: "accepted"`, and read every rule that
   applies to the code you will write. A rule that names no path reaches you this way.
2. Before you state how this system behaves, search the topic. Cite the document,
   or say that none exists.
3. If an accepted document conflicts with the task, tell the user before you edit.
4. If a search is empty, read `near_misses` and retry with fewer words before you
   conclude that no document exists.
5. When a decision is made ("we'll use X", "from now on Y"), record it.
6. When a module, API, or system you touched has no document, offer to capture it.

If the Archcore MCP tools are missing or fail to connect, tell the user once, then
take the file route above. Do not write `.archcore/` files by hand.

A `.archcore/` may also mount read-only **global sources** — shared, org-wide
context. `list_documents` / `search_documents` surface them alongside local docs,
tagged `source_kind: "global"`. When present, treat them as defaults a local doc
can override — never edit or relate to one.

Skip these steps only for turns this repo would have no opinion on: syntax
trivia, throwaway snippets, pure mechanics.
<!-- archcore:end -->
