# S005 Success Criteria

| ID | Criterion |
|----|-----------|
| S005-SC-001 | A mediated invocation checks in and uses only a daemon-issued session token and identity. |
| S005-SC-002 | Allowed exact command arguments execute; denied commands spawn no process and return the reason. |
| S005-SC-003 | Network and file forms are verified as non-executing probes; S015 tests verify real egress enforcement. |
| S005-SC-004 | Daemon loss during a long-running child kills and reaps that child, then exits 5. |
| S005-SC-005 | Malformed, oversized, timed-out, or unsuccessful API responses cannot start an action. |
| S005-SC-006 | Exit codes are 0 for success, 1 for action denial/failure, and 5 for enforcement unavailability. |
| S005-SC-007 | Shim diagnostics are on stderr and API bodies are bounded to 64 KiB. |
| S005-SC-008 | When helper mounts are enabled, the shim is read-only and no host operator socket is mounted. |
| S005-SC-009 | Built-in recipes remain secure with helper mounts disabled because S015 is the mandatory outer boundary. |
