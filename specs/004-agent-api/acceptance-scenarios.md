# S004 Acceptance Scenarios

### S004-AS-001 Check-in: happy path [P1]

**Given** `outcalld` is running and the agent socket is available at `/run/outcall/agent.sock`
**And** the calling process is inside a known container
**When** the agent sends `POST /v1/checkin`
**Then** the response contains a container ID, a session token, and expected context keys
**And** the HTTP status is 200.

### S004-AS-002 Permission granted [P1]

**Given** the agent has checked in and holds a valid session token
**And** a rule exists that allows the requested action
**When** the agent sends `POST /v1/permissions/check` with `action_type: "tool_exec"`, `target: "read_file"`, and the session token
**Then** the response is a `Verdict` with `allowed: true`
**And** `matched_rule` contains an opaque rule ID (not the rule body)
**And** the HTTP status is 200.

### S004-AS-003 Permission denied [P1]

**Given** the agent has checked in and holds a valid session token
**And** no rule allows the requested action (default-block)
**When** the agent sends `POST /v1/permissions/check` with `action_type: "network_call"`, `target: "https://evil.example.com"`
**Then** the response is a `Verdict` with `allowed: false`
**And** `reason` contains a human-readable denial message
**And** the HTTP status is 200.

### S004-AS-004 Fail closed: socket missing [P1]

**Given** the agent socket file does not exist at the expected path
**When** `outcall-agent` starts
**Then** it prints an error message to stderr
**And** exits with code 5 (`UNREACHABLE_EXIT_CODE`)
**And** no tool execution or network calls are attempted.

### S004-AS-005 Fail closed: daemon crashes mid-request [P1]

**Given** `outcalld` crashes or is killed while the agent has an in-flight permission request
**When** the agent's HTTP request fails (connection reset)
**Then** `outcall-agent` treats the action as denied
**And** exits with code 5.

### S004-AS-006 Rule request: submitted [P2]

**Given** the agent has checked in and holds a valid session token
**When** the agent sends `POST /v1/requests/rules` with a complete valid `rule_file`
**Then** the response contains a rule request ID and status `"pending"`
**And** the HTTP status is 201.

### S004-AS-007 Rule request: status polled [P2]

**Given** the agent previously submitted a rule request with ID `rr-abc123`
**When** the agent sends `GET /v1/requests/rules/rr-abc123`
**Then** the response contains the current status (`pending`, `approved`, or `rejected`)
**And** if rejected, a reason is included.

### S004-AS-008 No cross-container leakage [P1]

**Given** two agent containers (A and B) are running
**And** container A has checked in
**When** container A sends a permission request
**Then** the verdict is evaluated only against container A's policies
**And** the response contains no information about container B (no ID, no policies, no state).

### S004-AS-009 Context variables forwarded to rule engine [P1]

**Given** the agent has checked in
**When** the agent sends a permission request with `action_type`, `target`, and `metadata`
**Then** `outcalld` forwards all context variables to the rule engine (S003) for evaluation
**And** the `metadata` key-value pairs are available under `run.context` in rule conditions.

### S004-AS-010 Rate limit enforced [P2]

**Given** the agent has checked in
**When** the agent sends more than 100 permission requests within 10 seconds
**Then** subsequent requests receive HTTP 429 with an `AgentApiError::RateLimited` response
**And** the response includes a `Retry-After` header in seconds.

### S004-AS-011 Request timeout respected [P1]

**Given** the agent has checked in
**And** rule evaluation is artificially delayed beyond the configured timeout (default 5s)
**When** the agent sends a permission request
**Then** the response is a `Verdict` with `allowed: false` and `reason: "evaluation timeout"`
**And** the response arrives within the timeout duration (does not hang).
