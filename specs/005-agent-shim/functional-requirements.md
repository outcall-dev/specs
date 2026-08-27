# S005 Functional Requirements

## Socket And Identity

S005-FR-001 [P1] The shim **MUST** use `/run/outcall/agent.sock`, defined by
`DEFAULT_AGENT_SOCKET`, and **MUST NOT** connect to the host control socket.

S005-FR-002 [P1] Before a policy-mediated invocation, the shim **MUST** connect
to the agent socket. `--help` and `--version` **MAY** return static output without
daemon access.

S005-FR-003 [P1] The shim **MUST** check in before requesting a verdict and
**MUST NOT** assert its own hostname, PID, or container identity. `outcalld`
**MUST** derive identity from Unix peer credentials and Docker state, then return
the container ID and a session token.

S005-FR-004 [P1] Failed reachability, check-in, or authentication **MUST** exit
with `UNREACHABLE_EXIT_CODE` (5). No requested command may start first.

S005-FR-005 [P1] Agent API traffic **MUST** use only the agent socket. The shim
**MUST NOT** read daemon configuration or use the host operator API.

S005-FR-006 [P1] Release builds **MUST** provide a static shim binary. When
helper mounts are requested, the daemon **MUST** mount that binary read-only at
`/usr/local/bin/outcall`. Helper mounts are optional and are not the recipe
network security boundary.

## Explicit Command Mediation

S005-FR-007 [P1] `outcall exec <program> [args...]`, shell forms, and implicit
`outcall <program> [args...]` **MUST** request a verdict before spawning the
program. The request **MUST** preserve the exact argument vector in structured
metadata as well as the action type and target.

S005-FR-008 [P1] An allow verdict **MUST** spawn the exact requested program and
arguments without shell re-parsing. The shim **MUST** return success only when
the child succeeds.

S005-FR-009 [P1] A deny verdict **MUST NOT** spawn a child. The denial reason
**MUST** be written to stderr and the shim **MUST** return exit code 1.

S005-FR-010 [P1] `fetch`/`http`/`https` and `file`/`read`/`write` forms **MUST**
perform permission probes only. They **MUST NOT** claim to execute or intercept
the corresponding operation. Mandatory network enforcement belongs to S015.

S005-FR-022 [P1] The shim **MUST** preserve the denial reason for the caller and
**SHOULD** include `matched_rule` and `reason` in structured verdict diagnostics.

## Fail Closed And Lifecycle

S005-FR-011 [P1] A malformed, oversized, contradictory, or non-success agent API
response **MUST** be treated as daemon unreachability and exit with code 5.

S005-FR-012 [P1] If the daemon becomes unreachable while a mediated child is
running, the shim **MUST** terminate and reap the child before exiting with code
5. `kill_on_drop` **MUST** remain a fallback.

S005-FR-013 [P1] Socket checks and API requests **MUST** have a timeout.

S005-FR-014 [P2] `OUTCALL_TIMEOUT_SECS` **MUST** be an integer from 1 through
300. An absent value defaults to 30 seconds; malformed or out-of-range values
**MUST NOT** silently fall back.

S005-FR-019 [P1] While waiting for a verdict or child process, the shim **MUST**
periodically verify daemon socket reachability. A failed heartbeat **MUST**
trigger S005-FR-012.

S005-FR-020 [P1] On SIGTERM, the shim **MUST** stop beginning new work, allow the
current API request or child to finish, stop the heartbeat, and exit 0.

## Exit Codes And Logging

S005-FR-015 [P1] Exit code 0 means successful completion, 1 means a blocked or
failed requested action, and 5 means the enforcement daemon became unavailable.

S005-FR-016 [P1] Diagnostics **MUST** go to stderr. Child stdout/stderr remain
attached to the caller.

S005-FR-017 [P1] Logs **MUST NOT** be sent over the agent socket.

S005-FR-018 [P2] Diagnostics **SHOULD** use `tracing` with `component=shim`.

S005-FR-021 [P2] The shim **SHOULD** log the trusted container ID returned by
check-in. Policy identity remains daemon-owned and cannot be overridden by shim
request metadata.
