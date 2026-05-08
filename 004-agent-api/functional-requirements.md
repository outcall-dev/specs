# S004 Functional Requirements

### Socket lifecycle

S004-FR-001 [P1] `outcalld` **MUST** create the `agent.sock` Unix domain socket. The agent process **MUST NOT** create, bind, or modify the socket. The socket is a server socket owned by `outcalld`.

S004-FR-002 [P1] The default socket path **MUST** be `/run/outcall/agent.sock`, defined as `DEFAULT_AGENT_SOCKET` in `outcall-api`. The path **MUST** be configurable via `outcalld --agent-socket <path>`.

S004-FR-003 [P1] `outcalld` **MUST** remove the socket file on clean shutdown (SIGINT, SIGTERM). If the socket file already exists at startup, `outcalld` **MUST** remove it before binding (stale socket recovery).

### Agent check-in

S004-FR-004 [P1] The agent API **MUST** provide a check-in endpoint that accepts an empty request body, derives container identity host-side from `SO_PEERCRED`, and returns:
S004-FR-004.a A container ID that uniquely identifies the agent's container (derived from Docker metadata using the verified peer PID, not agent-supplied).
S004-FR-004.b A session token for subsequent requests (opaque string, not a JWT).
S004-FR-004.c The set of context keys the agent **SHOULD** include with permission requests.

S004-FR-005 [P1] `outcalld` **MUST** verify the calling container's identity by correlating the Unix socket peer credentials (`SO_PEERCRED`) with known container PIDs. If the peer cannot be mapped to a known container, the check-in **MUST** be rejected with HTTP 403.

### Permission requests

S004-FR-006 [P1] The agent API **MUST** provide a permission check endpoint. The agent sends a request describing the action it intends to take, and `outcalld` returns a `Verdict`.

S004-FR-007 [P1] The `Verdict` response **MUST** contain:
S004-FR-007.a `allowed` (boolean) -- whether the action may proceed.
S004-FR-007.b `matched_rule` (optional string) -- an opaque rule identifier, not the rule body.
S004-FR-007.c `reason` (optional string) -- a human-readable explanation safe to show to the agent.

S004-FR-008 [P1] All rule evaluation **MUST** happen host-side inside `outcalld`. The agent API **MUST NOT** send rule definitions, policy documents, or evaluation logic to the agent.

### Fail-closed semantics

S004-FR-009 [P1] If the agent socket is missing or `outcalld` is unreachable, `outcall-agent` **MUST** exit with code 5 (`UNREACHABLE_EXIT_CODE`). There **MUST** be no retry loop, no fallback, and no degraded mode.

### Trust boundary

S004-FR-010 [P1] The agent API **MUST NOT** expose:
S004-FR-010.a Rule definitions, conditions, or match expressions.
S004-FR-010.b The host socket path or any host API endpoints.
S004-FR-010.c Information about other containers (IDs, names, policies).
S004-FR-010.d Network topology, bridge configuration, or nftables state.
S004-FR-010.e `outcalld` internal configuration or daemon state.

### Rule requests

S004-FR-011 [P2] The agent API **MUST** provide an endpoint for agents to submit rule requests. A rule request body **MUST** contain a complete, valid rule file in the S003 YAML format (S003-IF-012). `outcalld` **MUST** parse and validate the rule file before queuing; malformed or invalid files **MUST** be rejected with HTTP 422. The request is queued for host operator approval and is not auto-applied.

S004-FR-012 [P2] The agent API **MUST** provide an endpoint for agents to query the status of a previously submitted rule request by its ID. The response **MUST** return the `RuleRequestStatus` (Pending, Approved, Rejected) and an optional reason.

### Context variables

S004-FR-013 [P1] Each permission request **MUST** include context variables describing the action:
S004-FR-013.a `action_type` (required) -- the category of action: `tool_exec`, `network_call`, `file_access`, or `shell_exec`.
S004-FR-013.b `target` (required) -- the specific resource: a tool name, URL/host, file path, or command.
S004-FR-013.c `metadata` (optional) -- a key-value map of additional context (HTTP method, port, arguments, etc.).
S004-FR-013.d The session token from check-in (required).

### Rate limiting

S004-FR-014 [P2] `outcalld` **MUST** enforce per-container rate limits on the agent API:
S004-FR-014.a Permission requests: max 100 requests per 10-second sliding window per container.
S004-FR-014.b Rule request submissions: max 10 per minute per container.
S004-FR-014.c Check-in: max 1 successful check-in per container lifecycle. Subsequent check-ins **MUST** return the existing session.

### Timeout behavior

S004-FR-015 [P1] Permission requests **MUST** time out after a configurable duration (default: 5 seconds). If rule evaluation does not complete within the timeout, the agent API **MUST** return a deny verdict with reason `"evaluation timeout"`. The default **MUST** be configurable via `outcalld --agent-timeout <duration>`. Note: this is the server-side evaluation timeout — it returns a deny verdict to the shim. The shim (S005-FR-014) has a separate, longer socket-level timeout (default 30s) that detects daemon unreachability and triggers exit code 5. These are intentionally different layers.

### Observability

S004-FR-016 [P1] All agent API operations (check-in, permission check, rule request, status query) **MUST** emit structured log events via the `tracing` crate, including the container ID and action type.

S004-FR-017 [P1] Agent API errors **MUST** use typed error variants (`AgentApiError`) via `thiserror`:
S004-FR-017.a `SocketBind` -- failed to bind the agent socket.
S004-FR-017.b `PeerIdentification` -- failed to extract or verify peer credentials.
S004-FR-017.c `CheckinRejected` -- container identity could not be verified.
S004-FR-017.d `EvaluationTimeout` -- rule evaluation did not complete in time.
S004-FR-017.e `RateLimited` -- request rejected due to rate limiting.
S004-FR-017.f `InvalidRequest` -- malformed or oversized request body.

### Daemon integration

S004-FR-018 [P1] The agent API **MUST** run as a Tokio task within the `outcalld` process, separate from the host API task. The agent socket listener **MUST** be an independent `axum` router bound to the agent socket path.

S004-FR-019 [P1] The host socket (`host.sock`) and agent socket (`agent.sock`) **MUST** be separate listeners on separate Unix domain sockets. The agent socket **MUST NOT** serve any host API routes. The host socket **MUST NOT** serve any agent API routes.
