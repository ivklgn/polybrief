# Refute pattern example

[refute.md](refute.md) is an optional pattern. Two workers review a change,
then each checks the other's findings. It is supplied as a file path because
it is not a built-in pattern. [polybrief.conf](polybrief.conf) configures both workers.

From the repository checkout:

```bash
polybrief -C /path/to/repo -b main -p examples/refute/refute.md --config examples/refute/polybrief.conf examples/code-review/brief.md
```

The caller still checks the evidence and makes the final decision.
