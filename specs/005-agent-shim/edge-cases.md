# S005 Edge Cases

| ID | Scenario | Expected Behavior |
|----|----------|-------------------|
| S005-EC-001 | `agent.sock` does not exist at startup | Shim logs error to stderr and exits with code 5. No retry. |
| S005-EC-002 | `agent.sock` disappears mid-session (file deleted or unmounted) | Next request or heartbeat fails with connection error. Shim exits with code 5. |
| S005-EC-003 | `outcalld` crashes while a check request is in flight | The socket returns a broken pipe or connection reset. Shim exits with code 5. The in-flight action is **not** executed (fail closed). |
| S005-EC-004 | `outcalld` is alive but does not respond within timeout | After the timeout (default 30s), the shim treats it as unreachable. Shim exits with code 5. |
| S005-EC-005 | `outcalld` returns a malformed response (invalid JSON, missing fields) | Shim treats malformed responses as a block verdict (S005-FR-011). Logs the parse error to stderr. Does not exit — only the specific action is denied. |
| S005-EC-006 | Agent sends multiple concurrent tool invocations | Each invocation is checked independently via its own request to `outcalld`. Requests are serialized or multiplexed per the agent API protocol (S004). No request bypasses the check. |
| S005-EC-007 | `outcalld` rejects the registration (unknown container, policy violation) | Shim logs the rejection reason to stderr and exits with code 5. The agent cannot run without successful registration. |
| S005-EC-008 | `agent.sock` exists as a file but nothing is listening (stale socket) | Connection attempt fails. Shim exits with code 5. The `exists()` check passes but the connect fails — this is why S005-FR-002 requires a connection attempt, not just a path check. |
| S005-EC-009 | Agent process attempts to overwrite or delete `/usr/local/bin/outcall` | The bind mount is read-only. The write/delete syscall returns `EROFS`. Shim binary is unaffected. |
| S005-EC-010 | `agent.sock` flaps (disappears and reappears rapidly) | The shim does not attempt reconnection. On the first failure, it exits with code 5. Reconnection is not the shim's job — the container orchestrator should restart the container. |
