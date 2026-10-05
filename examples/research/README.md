# Research example

[brief.md](brief.md) asks workers to compare two architecture approaches using
evidence from a project. The built-in `research` pattern first collects
independent answers, then asks each worker to check the other's answer.
[polybrief.conf](polybrief.conf) selects that pattern and configures both workers.

From the repository checkout:

```bash
polybrief -C /path/to/project --config examples/research/polybrief.conf examples/research/brief.md
```

The caller checks the sources and decides which conclusions to use.
