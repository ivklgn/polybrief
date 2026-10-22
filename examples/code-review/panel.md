---
name: panel
description: Each reviewer takes one lens. Codex looks for security holes and missing tests, Claude for design and the stack.
workers: codex, claude
max-calls: 4
---

## review

- run: codex as risk with review-security+review-tests
- run: claude as design with run
- expect: ^(FINDING|NOT-CHECKED|NO FINDINGS)
- retry: 1

{{brief}}

### Your lens: {{role}}

Other reviewers cover the other lenses. Your lens overrides the focus named in the brief above.
Put your effort into the concerns of your lens:

- risk: correctness on failure, empty and concurrent paths; security and data safety; tests that would fail if the change broke. Use the supplied checklists.
- design: the intent of the change; fit with the surrounding code and its idioms; contracts and interfaces; completeness; rollout and migration. Any checklist you received is context, not your lens.

Report a problem outside your lens only when you are sure of it and it is serious.
