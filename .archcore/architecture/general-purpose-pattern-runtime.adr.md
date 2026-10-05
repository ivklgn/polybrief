---
title: "Polybrief is a general pattern runtime with a read-only first profile"
status: accepted
tags:
  - "architecture"
  - "polybrief"
---

## Context

The Go binary runs a brief through a Markdown pattern. A pattern names the
participants, stages, answer handoffs, conditions, retries, and gates
(@.archcore/runtime/polybrief-pattern-file.spec.md). The launcher starts the local
agent CLIs and owns their execution settings (@launch.go). Research and code
review were useful first cases for the read-only implementation and its
measurements (@.archcore/research/polybrief-measured-runs.rnd.md), but they do not
define the intended range of tasks.

The current launcher gives Codex a read-only sandbox and Claude only reading
tools; the runner writes outside the target directory. This is an implemented
capability boundary, not a permanent product boundary. Code writing would
require a different capability and isolation contract.

## Decision

Position Polybrief as a general-purpose pattern runtime for local agent CLIs. It
executes caller-supplied briefs through explicit patterns and returns the
artifacts and status of each worker call. A task category is not built into the
public run command or the pattern format.

- The current release supports read-only worker execution. Its first worked
  examples are research and code review (@examples/README.md).
- Write-capable work, including code writing, remains a possible extension.
  It must be introduced with explicit permissions, workspace isolation,
  conflict handling, and result verification rather than by weakening the
  existing read-only profile.
- The current caller supplies the brief and evaluates the results. Automated
  final decisions, if added later, need their own contract.

## Alternatives Considered

1. Define the product as a research and code-review tool. This matches the
   first measured cases but would turn examples into a permanent scope limit.
2. Enable code writing in the current worker profile. Deferred: the existing
   launcher and its tests promise read-only execution, and concurrent edits
   need an explicit ownership and verification design.
3. Define the product as a self-organizing agent swarm. Rejected as a technical
   description of this implementation: the runner selects and routes work
   from a declared pattern; workers do not independently reassign it.

## Consequences

- The README describes the mechanism first; research and code review live in
  `examples/` and can have detailed guides without defining product scope.
- Current CLI behavior and isolation flags do not change under this decision.
- Results measured on review cases support claims about those cases only. They
  do not establish quality or cost for other patterns or future write modes.
- The current read-only contract stays testable. A write-capable extension will
  need a separate decision and changes to the affected runtime contracts.

## Superseded when

Revisit if patterns cease to be the public unit of execution or if task
categories become enforced by the runtime rather than expressed by callers.
