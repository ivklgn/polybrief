---
title: "Keep three general built-in patterns; move task-fit and role presets to callers"
status: accepted
tags:
  - "architecture"
  - "polybrief"
---

## Context

The owner chose on 2026-10-22 to remove the built-in `intent` and `panel` presets while preserving their workflows in skills and examples. The one-stage `intent` differs from `parallel` by its answer contract; the brief contains the task-fit method. `panel` divides one stage into review lenses and selects checklists. Recorded measurements do not establish a quality gain for those fixed lenses.

## Decision

Keep `parallel`, `twice` and `crosscheck` embedded in @patterns/. Remove the embedded `intent` and `panel` names without aliases. This replaces only the built-in-name portions of the earlier decisions; the Go runtime, argument-only interface and base snapshots remain.

Task-fit skills use `parallel` with `-o 'expect=^(CONFLICT|MISSING|EXTRA|UNCLEAR|MATCH|SUMMARY)'`, their comparison brief and `-c task.md`. The optional specification remains `-c spec.md`. @examples/done-check/SKILL.md keeps two independent calls and reads answers under `review/1`.

Move the panel definition to @examples/code-review/panel.md as a caller-owned pattern. Users copy it outside the reviewed directory and pass its path with the named security and test checklists. The launcher and pattern language retain roles, checklist selection, retries and `at base`.

Update known ivklgn-kit consumers with the runtime: its intent pass keeps its user-facing switch and uses `parallel` with the row override; `deep:panel` leaves its resolver.

## Alternatives Considered

1. Keep both names as presets: rejected because the owner chose a smaller built-in selection and caller-owned scenario instructions.
2. Keep hidden aliases: rejected because they retain the removed built-in contracts and delay migration.
3. Delete role-based review entirely: rejected because a custom pattern still demonstrates supported runtime features.

## Consequences

- Existing `-p intent` calls need `parallel` plus the explicit row override. Existing `-p panel` calls need a custom pattern path.
- The migration changes task-fit artifact paths from `compare/1` to `review/1`.
- `expect` accepts an answer with at least one matching line; it does not prove row completeness or correctness.
- Historical measurements keep the pattern names used in those runs.
- @tests/test_cli.sh exercises copied skills, the custom panel and row-contract override with fake workers, without model quota.

## Superseded when

- Revisit if a scenario needs runtime behavior that callers cannot express with the public options or a custom pattern.
- [assumption] Revisit if user feedback shows that the smaller built-in selection makes common workflows harder to run.
