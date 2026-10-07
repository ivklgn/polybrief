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

Other reviewers cover the other lenses. Put your effort into the concerns of your lens:

- risk: 2 Correctness on failure, empty and concurrent paths; 6 Security and data safety; 8 Tests.
- design: 1 Intent, 3 Design and fit, 4 Contracts, 5 Completeness, 10 Rollout, and the stack checklists.

Report a problem outside your lens only when you are sure of it and it is serious.
