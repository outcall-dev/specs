# S004 Success Criteria

| ID | Criterion |
|----|-----------|
| S004-SC-001 | After `outcalld` starts, a process inside an agent container can `POST /v1/checkin` to the agent socket and receive a valid container ID and session token. |
| S004-SC-002 | E2E test: an agent checks in, requests permission for an allowed tool, receives `allowed: true`, requests permission for a blocked tool, receives `allowed: false` -- proving round-trip verdict flow works. |
| S004-SC-003 | E2E test: when `outcalld` is stopped (socket removed), `outcall-agent` exits with code 5 within 1 second. No tool execution occurs. |
| S004-SC-004 | E2E test: a permission response never contains rule conditions, policy documents, host configuration, other container IDs, or bridge/network state. Validated by schema-checking all response fields against an allowlist. |
| S004-SC-005 | E2E test: an agent submits a rule request, receives a pending ID, the host operator approves it via the host API, and the agent's status query returns `approved`. |
