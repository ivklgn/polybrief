---
name: review-security
description: Security and data safety of a change.
---

Check the change for security and data-safety problems. Follow untrusted input from
where it enters the changed code to where it is used.

- Injection: input that reaches SQL, a shell, a file path, HTML, a template or a regular
  expression without escaping or validation.
- Access: a new or changed endpoint, command or handler without the authentication and
  authorization checks its neighbours have.
- Secrets: keys, tokens or passwords in code, logs, error messages or test data.
- Data exposure: personal or internal data in responses, logs or analytics that did not
  hold it before.
- Unsafe defaults: a debug flag, a wide CORS rule, a disabled TLS check, a world-readable file.
- Dependencies: a new package or version with a known problem, or one that is not needed.

Report a problem only with the line that causes it and a concrete way to exploit it.
