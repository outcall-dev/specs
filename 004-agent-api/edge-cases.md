# S004 Edge Cases

| ID | Scenario | Expected Behavior |
|----|----------|-------------------|
| S004-EC-001 | Agent socket file missing when `outcall-agent` starts | `outcall-agent` prints `agent socket not found at /run/outcall/agent.sock -- is outcalld running?` to stderr and exits with code 5. No retry. |
| S004-EC-002 | `outcalld` crashes while an agent has an in-flight permission request | The agent's HTTP connection resets. `outcall-agent` treats any connection failure as unreachable, denies the pending action, and exits with code 5. |
| S004-EC-003 | Agent sends a malformed JSON body (invalid syntax, wrong types) | `outcalld` returns HTTP 400 with `"success": false` and a descriptive parse error. The action is not evaluated. |
| S004-EC-004 | Agent calls check-in twice with the same container identity | The second check-in **MUST** return the existing session token and container ID. It **MUST NOT** create a duplicate session or error. Idempotent. |
| S004-EC-005 | Permission request from a container that never checked in (unknown session token) | `outcalld` returns HTTP 401 with `"invalid or missing session token"`. No rule evaluation occurs. |
| S004-EC-006 | Agent exceeds the rate limit (>100 permission requests in 10s) | `outcalld` returns HTTP 429 with `Retry-After` header. Subsequent requests within the window are rejected without rule evaluation. Requests resume normally after the window slides. |
| S004-EC-007 | Rule evaluation exceeds the configured timeout (default 5s) | `outcalld` returns a deny `Verdict` with `allowed: false` and `reason: "evaluation timeout"`. The evaluation is cancelled. Fail-closed. |
| S004-EC-008 | Agent attempts to connect to `host.sock` (the host API socket) | `host.sock` is never mounted into containers. If an agent somehow crafts a path to it, the filesystem mount prevents access. If a request arrives on `host.sock` from a container PID, it **MUST** be rejected. |
| S004-EC-009 | Agent submits a rule request for a capability already covered by an existing rule | The request is accepted and queued normally (status `pending`). The host operator decides whether to approve, reject, or ignore duplicates. `outcalld` does not auto-deduplicate. |
| S004-EC-010 | Agent sends a request body exceeding the maximum size (default 64 KB) | `outcalld` returns HTTP 413 with `"request body too large"`. The connection is not dropped -- subsequent well-formed requests are accepted. |
