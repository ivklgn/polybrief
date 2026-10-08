---
name: review-tests
description: Whether tests guard the changed behavior.
---

Check whether the tests guard the behavior this change adds or changes.

- Each new or changed behavior has a test that fails when the behavior breaks.
- Failure paths are tested: empty input, errors from calls, timeouts, concurrent use.
- A test checks the result, not only that the code ran without an error.
- A changed test still checks what it checked before, or the change says why not.
- A bug fix has a test that fails without the fix.

Report a missing test with the behavior it should guard and the file where it belongs.
