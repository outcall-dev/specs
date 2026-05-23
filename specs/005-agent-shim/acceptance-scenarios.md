# S005 Acceptance Scenarios

### S005-AS-001 Startup: happy path [P1]

**Given** `outcalld` is running and `agent.sock` is bind-mounted into the container
**And** the socket is accepting connections
**When** the shim starts
**Then** it connects to `agent.sock` and sends a registration message
**And** `outcalld` acknowledges the registration
**And** the shim begins its heartbeat loop
**And** the shim logs `registered with outcalld` to stderr.

### S005-AS-002 Startup: socket missing [P1]

**Given** `agent.sock` does not exist at `/run/outcall/agent.sock`
**When** the shim starts
**Then** it logs `agent socket not found at /run/outcall/agent.sock` to stderr
**And** exits with code 5.

### S005-AS-003 Tool invocation: allow verdict [P1]

**Given** the shim is registered and running
**And** the agent policy allows `bash` commands matching `ls /tmp`
**When** the agent invokes `outcall bash ls /tmp`
**Then** the shim sends a check request with tool=`bash`, args=`ls /tmp` to `outcalld`
**And** `outcalld` returns `Verdict { allowed: true, matched_rule: Some("..."), reason: None }`
**And** the shim executes `ls /tmp`
**And** returns the output to the agent process.

### S005-AS-004 Tool invocation: block verdict [P1]

**Given** the shim is registered and running
**And** the agent policy blocks `bash` commands matching `rm -rf /`
**When** the agent invokes `outcall bash rm -rf /`
**Then** the shim sends a check request to `outcalld`
**And** `outcalld` returns `Verdict { allowed: false, reason: Some("destructive command blocked by policy") }`
**And** the shim does **not** execute the command
**And** returns an error to the agent including the reason string
**And** logs the block event to stderr.

### S005-AS-005 Network request: allowed [P1]

**Given** the shim is registered and running
**And** the policy allows HTTPS to `api.openai.com:443`
**When** the agent requests an outbound HTTPS connection to `api.openai.com:443`
**Then** the shim sends a network check request to `outcalld`
**And** `outcalld` returns `Verdict { allowed: true }`
**And** the shim permits the connection.

### S005-AS-006 Network request: blocked [P1]

**Given** the shim is registered and running
**And** the policy does not allow connections to `evil.example.com`
**When** the agent requests an outbound connection to `evil.example.com:443`
**Then** the shim sends a network check request to `outcalld`
**And** `outcalld` returns `Verdict { allowed: false, reason: Some("destination not in allowlist") }`
**And** the shim refuses the connection
**And** returns an error to the agent with the reason.

### S005-AS-007 Mid-session: outcalld crashes [P1]

**Given** the shim is registered and running with an active heartbeat
**When** `outcalld` crashes (agent.sock becomes a broken pipe)
**Then** the next heartbeat or check request fails
**And** the shim logs `outcalld unreachable — exiting (fail closed)` to stderr
**And** the shim exits with code 5.

### S005-AS-008 Request timeout [P1]

**Given** the shim is registered and running
**And** `outcalld` is alive but stalled (not responding to requests)
**When** the agent invokes a tool through the shim
**Then** the shim sends the check request
**And** after 30 seconds with no response, the shim treats it as unreachable
**And** the shim exits with code 5.

### S005-AS-009 Graceful shutdown [P2]

**Given** the shim is registered and has a check request in flight
**When** the container receives SIGTERM
**Then** the shim stops accepting new requests
**And** waits for the in-flight request to complete (up to the timeout)
**And** exits with code 0.

### S005-AS-010 Binary immutability [P1]

**Given** the shim is bind-mounted read-only at `/usr/local/bin/outcall`
**When** the agent process attempts to overwrite, delete, or chmod the shim binary
**Then** the filesystem returns a read-only error
**And** the shim binary remains unchanged.
