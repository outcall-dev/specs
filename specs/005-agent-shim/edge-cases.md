# S005 Edge Cases

| ID | Scenario | Expected Behavior |
|----|----------|-------------------|
| S005-EC-001 | Agent socket absent at startup | Exit 5 before check-in or child spawn. |
| S005-EC-002 | Agent socket disappears mid-action | Heartbeat or API call fails; active child is killed and reaped; exit 5. |
| S005-EC-003 | Daemon stalls during a check | Timeout expires; no child starts; exit 5. |
| S005-EC-004 | Timeout environment is malformed, zero, or over 300 | Configuration is rejected; exit 5 rather than silently using a default. |
| S005-EC-005 | API response is malformed or exceeds 64 KiB | Treat daemon channel as untrustworthy; do not execute; exit 5. |
| S005-EC-006 | Several shim processes run concurrently | Each checks in and receives its own session; daemon per-container rate limits still apply. |
| S005-EC-007 | Check-in peer cannot be mapped to a managed container | Daemon returns 403; shim exits 5. |
| S005-EC-008 | Socket path exists but no listener accepts | Connection fails; shim exits 5. |
| S005-EC-009 | Agent tries to overwrite an enabled helper mount | Read-only bind mount rejects the write. |
| S005-EC-010 | `fetch` or `file` receives an allow verdict | Probe exits 0 but performs no network or file operation. |
| S005-EC-011 | Requested child exits with any nonzero status | Shim returns action-error exit code 1. |
| S005-EC-012 | SIGTERM arrives while verdict is pending | Finish the in-flight verdict request, start no child, and exit 0. |
