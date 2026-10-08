# Contributing to polybrief

Thanks for your interest in polybrief. Bug reports, fixes, new patterns, and
documentation improvements are all welcome.

## Report a bug or ask for a feature

Open an [issue](https://github.com/ivklgn/polybrief/issues). For a bug, include:

- `polybrief --version`, your OS, and the agent CLIs you use (`codex`, `claude`, `opencode`) with their versions;
- the command you ran and the brief (remove private data);
- what you expected and what happened;
- the `RESULT` line and the relevant logs from the `OUT <dir>` folder.

For a larger change, open an issue first so we can agree on the approach before you write code.

## Security

Do not report security problems in a public issue. Use
[GitHub private vulnerability reporting](https://github.com/ivklgn/polybrief/security/advisories/new).

## Development setup

You need Go 1.25+ and `bash`. The checks use fake workers, so you do not need
the agent CLIs and spend no model quota.

```bash
git clone https://github.com/ivklgn/polybrief.git
cd polybrief
go build -o polybrief .
```

## Before you open a pull request

Run the same checks as CI:

```bash
gofmt -l .        # must print nothing
go vet ./...
go test ./...
bash tests/test_review.sh
bash tests/test_pattern.sh
bash tests/test_cli.sh
```

Project rules:

- **Standard library only.** Do not add dependencies to `go.mod`.
- **Workers stay read-only.** Do not add write access to workers without an agreed design.
- **Keep code in its place.** Worker startup and isolation flags live in `launch.go`
  (and `launch_unix.go`, `launch_windows.go`); configuration parsing lives in
  `config.go`; `runner.go` starts workers only through the launcher.
- **Add a test** for each behavior change or bug fix.
- **Update the docs** (`README.md` and the relevant `.archcore/` contract or reference) when you change flags, patterns, or output.
- **Design records.** Architecture decisions and runtime contracts live in
  `.archcore/`. Read the related spec before you change behavior, and update it
  in the same pull request.

## Commits and pull requests

- Use [Conventional Commits](https://www.conventionalcommits.org/):
  `feat: ...`, `fix: ...`, `docs: ...`; mark breaking changes with `!` (`feat!: ...`).
- Keep one logical change per pull request, and describe what changed and why.
- Link the related issue, if there is one.

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).
