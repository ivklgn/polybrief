# Code review example

[brief.md](brief.md) asks for actionable findings. `-b` adds the Git change
from the chosen base to the working tree, including untracked files. The
default `parallel` pattern sends the same brief and change to independent
workers. [polybrief.conf](polybrief.conf) configures both workers.

From the repository checkout:

```bash
polybrief -C /path/to/repo -b main --config examples/code-review/polybrief.conf examples/code-review/brief.md
```

The caller checks each finding against the code before acting on it. For a
longer workflow, use a different pattern with the same brief.
