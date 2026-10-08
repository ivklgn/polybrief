---
title: "Polybrief built-in patterns and selection"
status: accepted
tags:
  - "polybrief"
---

## Overview

Lookup for the four patterns embedded in @patterns/. The main agent supplies the brief, reads worker answers, verifies claims, and makes the final decision. Workers use the read-only launcher profile.

## Content

| Pattern | Execution | Default calls | Use and limit |
|---|---|---:|---|
| `parallel` | Codex and Claude answer independently in one stage. | 2 | A second opinion on a change or question; each model gives one sample. |
| `twice` | Two Codex and two Claude calls answer independently in one stage. | 4 | More samples for a review; four calls spend more model quota. |
| `crosscheck` | Codex and Claude analyze independently; each then critiques the other answer. | 4 | Compare conclusions, evidence, assumptions, and disagreements; the critique does not verify claims for the caller. |
| `panel` | Codex reviews security and tests; Claude reviews design. | 2, up to 4 with retries | A review with supplied `review-security.md` and `review-tests.md` checklists. |

`parallel` is the default. Run `polybrief plan -p NAME` to see stages and the call limit before starting workers. `-w LIST` replaces workers in stages without `run:` lines (`parallel`, `crosscheck`) and filters the fixed participants in `twice` and `panel`. In `panel`, pass both named checklists with `-c FILE`.

Measured review runs in September and October 2026 found distinct issues in Codex and Claude answers. Their counts apply to the tested changes and CLI versions, not to a new release or to `crosscheck`. The recorded investigations hold the cases and results.

### Custom pattern

A custom pattern is one caller-owned Markdown file passed with `-p FILE`. Its header names the pattern and default workers. Each `##` heading starts a stage. `{{brief}}` inserts the task. Later stages can set `- input: others` and use `{{input}}` to receive other workers' earlier answers. The pattern-file spec owns the full syntax and limits.

## Examples

Independent answers from Codex and OpenCode: `polybrief -C ./repo -p parallel -w codex,opencode -o opencode.model=provider/model ./brief.md`.

Research with two analysis calls and two critiques: `polybrief -C ./repo -p crosscheck -w claude,codex ./brief.md`.

Create `my-check.md` with a header (`name`, `description`, `workers`) and one `## answer` stage containing `{{brief}}`. Validate with `polybrief plan -p ./my-check.md`, then run `polybrief -p ./my-check.md ./brief.md`.