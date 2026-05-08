# S005 Functional Requirements

### Socket and identity

S005-FR-001 [P1] The agent socket path **MUST** be `/run/outcall/agent.sock`, defined as a constant in the shim. The shim **MUST NOT** communicate with any other socket.

S005-FR-002 [P1] On startup, the shim **MUST** verify that `agent.sock` exists and is reachable by attempting a connection. A filesystem `exists()` check alone is insufficient — the shim **MUST** confirm the socket is accepting connections.

S005-FR-003 [P1] After confirming the socket is reachable, the shim **MUST** send a registration message to `outcalld` via the agent API (S004). Registration **MUST** include the container's identity (hostname, PID). The shim **MUST NOT** proceed until registration is acknowledged.

S005-FR-004 [P1] If the socket does not exist, is not reachable, or registration fails, the shim **MUST** exit with code 5 (`UNREACHABLE_EXIT_CODE` from `outcall-api`). This is fail-closed behavior — no agent action is possible without `outcalld`.

S005-FR-005 [P1] The shim **MUST** communicate exclusively via `/run/outcall/agent.sock`. It **MUST NOT** attempt to connect to `host.sock`, read `outcalld` config files, or access any other `outcalld` surface.

S005-FR-006 [P1] The shim binary **MUST** be statically linked (no dynamic library dependencies). It **MUST** be bind-mounted read-only into the container at `/usr/local/bin/outcall`. The container filesystem permissions **MUST NOT** allow the agent to modify, replace, or delete the binary.

### Tool invocation interception

S005-FR-007 [P1] When the agent process invokes a tool through the shim, the shim **MUST** submit a check request to `outcalld` via the agent API before executing the action. The request **MUST** include:
S005-FR-007.a The tool name (e.g., `bash`, `file_write`, `http_request`).
S005-FR-007.b The full arguments / parameters the agent supplied.
S005-FR-007.c The agent's registered identity.

S005-FR-008 [P1] If `outcalld` returns a `Verdict` with `allowed: true`, the shim **MUST** execute the requested action and return the result to the agent process.

S005-FR-009 [P1] If `outcalld` returns a `Verdict` with `allowed: false`, the shim **MUST NOT** execute the action. It **MUST** return an error to the agent process that includes the `reason` field from the verdict (if present).

S005-FR-022 [P1] The shim **MUST** pass the full `Verdict` response back to the agent process, including `matched_rule` and `reason` fields, so the agent can adapt its behavior.

### Network request gating

S005-FR-010 [P1] Before making any outbound network request on behalf of the agent, the shim **MUST** submit a network check request to `outcalld` via the agent API. The request **MUST** include:
S005-FR-010.a The destination host (domain name or IP).
S005-FR-010.b The destination port.
S005-FR-010.c The protocol (TCP, UDP, etc.).
S005-FR-010.d The request method and path (for HTTP/HTTPS requests).

### Default-block and fail-closed

S005-FR-011 [P1] If `outcalld` returns any response that is not a well-formed `Verdict`, the shim **MUST** treat it as a block. Ambiguity is always resolved as deny.

S005-FR-012 [P1] If `outcalld` becomes unreachable at any point after startup (socket error, connection refused, broken pipe), the shim **MUST** exit with code 5. It **MUST NOT** attempt to continue operating without policy enforcement.

S005-FR-013 [P1] Every request to `outcalld` **MUST** have a timeout. If `outcalld` does not respond within the timeout, the shim **MUST** treat it as unreachable and exit with code 5.

S005-FR-014 [P2] The default request timeout **SHOULD** be 30 seconds. This value **SHOULD** be configurable via an environment variable (`OUTCALL_TIMEOUT_SECS`).

### Heartbeat

S005-FR-019 [P1] After registration, the shim **MUST** run a background heartbeat loop that periodically pings `outcalld` via the agent API. If a heartbeat fails, the shim **MUST** exit with code 5.

### Exit codes

S005-FR-015 [P1] The shim **MUST** use the following exit codes:
S005-FR-015.a `0` — normal exit (agent completed successfully).
S005-FR-015.b `1` — agent error (the wrapped action failed, not a policy issue).
S005-FR-015.c `5` — `outcalld` unreachable (fail-closed). Defined as `UNREACHABLE_EXIT_CODE` in `outcall-api`.

### Logging and output

S005-FR-016 [P1] All shim diagnostic messages **MUST** be written to stderr. The shim **MUST NOT** write diagnostic output to stdout.

S005-FR-017 [P1] The shim **MUST NOT** send log messages over `agent.sock`. The socket is exclusively for API communication (check requests, verdicts, registration, heartbeats).

S005-FR-018 [P2] Log messages **SHOULD** use structured format via the `tracing` crate, consistent with `outcalld`'s logging conventions. Each log entry **SHOULD** include a `component=shim` field.

### Lifecycle

S005-FR-020 [P1] On receiving SIGTERM, the shim **MUST** stop accepting new requests, complete any in-flight request (up to the timeout), and exit cleanly with code 0.

S005-FR-021 [P2] The shim **SHOULD** propagate agent identity metadata (container ID, image name, labels) received during registration so that `outcalld` can use them in rule matching.
