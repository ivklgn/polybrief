---
title: "Polybrief built-in patterns and selection"
status: accepted
tags:
  - "polybrief"
---

## Overview

Lookup for the three patterns embedded in @patterns/. The main agent supplies the brief, reads worker answers, verifies claims, and makes the final decision. Workers use the read-only launcher profile.

## Content

| Pattern | Execution | Default calls | Use and limit |
|---|---|---:|---|
| `parallel` | Codex and Claude answer independently in one stage. | 2 | A second opinion on a change or question; each model gives one sample. |
| `twice` | Two Codex and two Claude calls answer independently in one stage. | 4 | More samples for a review; four calls spend more model quota. |
| `crosscheck` | Codex and Claude analyze independently; each then critiques the other answer. | 4 | Compare conclusions, evidence, assumptions, and disagreements; the critique does not verify claims for the caller. |

`parallel` is the default. Run `polybrief plan -p NAME` to see stages and the call limit before starting workers. `-w LIST` replaces workers in stages without `run:` lines (`parallel`, `crosscheck`) and filters the fixed participants in `twice`.

### Scenario migration

`intent` and `panel` are no longer built-in names. Task-fit checks use `parallel`, the row-format brief in @examples/done-check/references/brief.md and `-o 'expect=^(CONFLICT|MISSING|EXTRA|UNCLEAR|MATCH|SUMMARY)'`. Pass `-b`, `-c task.md` and optional `-c spec.md`. The override replaces the review answer contract selected by `-b`. Answers live under `review/1`, not the old `compare/1`. A matching line does not establish completeness or correctness.

Role-based review uses the caller-owned @examples/code-review/panel.md with supplied `review-security.md` and `review-tests.md` checklists. Copy the example outside the reviewed directory and pass its path with `-p FILE`. It still runs Codex as `risk` and Claude as `design`, with up to four calls including retries.

Measured review runs in September and October 2026 found distinct issues in Codex and Claude answers. Their counts apply to the tested changes and CLI versions, not to a new release or to `crosscheck`. The panel measurements do not establish a quality gain over independent review.

### Custom pattern

A custom pattern is one caller-owned Markdown file passed with `-p FILE`. Its header names the pattern and default workers. Each `##` heading starts a stage. `{{brief}}` inserts the task. Later stages can set `- input: others` and use `{{input}}` to receive other workers' earlier answers. `own` and `others` match participants across stages by name (the role, else the worker): a later stage that checks the other participant's answer repeats the same `run: <worker> as <role>` lines, or each worker gets every earlier answer. The pattern-file spec owns the full syntax and limits.

## Examples

Independent answers from Codex and OpenCode: `polybrief -C ./repo -p parallel -w codex,opencode -o opencode.model=provider/model ./brief.md`.

Research with two analysis calls and two critiques: `polybrief -C ./repo -p crosscheck -w claude,codex ./brief.md`.

Create `my-check.md` with a header (`name`, `description`, `workers`) and one `## answer` stage containing `{{brief}}`. Validate with `polybrief plan -p ./my-check.md`, then run `polybrief -p ./my-check.md ./brief.md`.
