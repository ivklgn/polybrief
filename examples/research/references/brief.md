Question: Should Polybrief keep one `timeout` setting for every worker call, or
add separate timeout overrides for Codex, Claude, and OpenCode?

Investigate the current code in this repository. Trace how `-o timeout=...`
is parsed, reaches the pattern runner and launcher, and stops a worker on Unix
and Windows. Cite exact file paths and functions or lines. Compare the two
options for failure behavior, CLI complexity, and testing. Recommend one
option for the current read-only runtime.

Separate observed behavior from inference. Name code or tests that would
falsify your conclusion. If the repository cannot answer a point, say so;
do not invent benchmarks or behavior of third-party CLIs. Do not change files.
