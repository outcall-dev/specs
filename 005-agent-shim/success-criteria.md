# S005 Success Criteria

| ID | Criterion |
|----|-----------|
| S005-SC-001 | After startup, the shim has a live connection to `agent.sock` and `outcalld` reports the agent as registered. |
| S005-SC-002 | E2E test: a tool invocation that matches an allow rule is executed and returns output to the agent. A tool invocation that matches a block rule is refused and the agent receives the deny reason. |
| S005-SC-003 | E2E test: an outbound network request to an allowed destination succeeds. A request to a blocked destination is refused before any bytes leave the container. |
| S005-SC-004 | When `outcalld` is killed mid-session, the shim exits with code 5 within one heartbeat interval. No agent action executes after `outcalld` becomes unreachable. |
| S005-SC-005 | After a block verdict, no side effects from the blocked action are observable (no process spawned, no file written, no network connection initiated). |
| S005-SC-006 | Exit code 0 is used only for successful completion, exit code 1 for agent errors, and exit code 5 exclusively for `outcalld` unreachable. No other exit codes are used. |
| S005-SC-007 | All shim log output appears on stderr. `agent.sock` traffic contains only API messages (check requests, verdicts, registration, heartbeats). stdout is reserved for agent output. |
| S005-SC-008 | From inside the container, `mount` or `/proc/mounts` shows `/usr/local/bin/outcall` as a read-only bind mount. Attempts to write to it fail with `EROFS`. |
