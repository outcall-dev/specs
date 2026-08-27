# S006 Acceptance Scenarios

### S006-AS-001 HTTP GET: request allowed [P1]

**Given** `outcalld` is running with the proxy listening on `10.200.0.1:8080`
**And** the rule engine has a rule allowing `network.hostname == "api.example.com"`
**And** an agent container has `HTTP_PROXY=http://10.200.0.1:8080`
**When** the agent makes an HTTP GET request to `http://api.example.com/v1/data`
**Then** the proxy extracts hostname `api.example.com`, method `GET`, path `/v1/data`
**And** the proxy evaluates the request against the rule engine
**And** the rule engine returns ALLOW
**And** the proxy forwards the request to `api.example.com`
**And** the agent receives the upstream response.

### S006-AS-002 HTTP GET: request blocked [P1]

**Given** `outcalld` is running with the proxy listening
**And** the rule engine has no rule allowing `network.hostname == "evil.example.com"`
**When** the agent makes an HTTP GET request to `http://evil.example.com/exfiltrate`
**Then** the proxy evaluates the request against the rule engine
**And** the rule engine returns BLOCK with a reason
**And** the proxy returns HTTP 403 to the agent
**And** the response body contains the block reason
**And** the request is **not** forwarded upstream.

### S006-AS-003 HTTPS CONNECT: tunnel allowed [P1]

**Given** `outcalld` is running with the proxy listening
**And** the rule engine allows `network.hostname == "api.github.com"`
**When** the agent opens an HTTPS connection to `api.github.com:443` via the proxy
**Then** the proxy receives a `CONNECT api.github.com:443` request
**And** the proxy peeks at the TLS ClientHello to extract SNI `api.github.com`
**And** the proxy evaluates with `network.hostname = "api.github.com"`, `http.method = "CONNECT"`
**And** the rule engine returns ALLOW
**And** the proxy responds with `200 Connection Established`
**And** the proxy tunnels raw bytes between the agent and `api.github.com:443`
**And** the TLS handshake completes end-to-end (proxy does not decrypt).

### S006-AS-004 HTTPS CONNECT: tunnel blocked [P1]

**Given** `outcalld` is running with the proxy listening
**And** the rule engine blocks `network.hostname == "malware.example.com"`
**When** the agent opens an HTTPS connection to `malware.example.com:443` via the proxy
**Then** the proxy receives `CONNECT malware.example.com:443`
**And** the proxy evaluates the request against the rule engine
**And** the rule engine returns BLOCK
**And** the proxy returns HTTP 403 with the block reason
**And** no tunnel is established
**And** no bytes are sent to `malware.example.com`.

### S006-AS-005 SNI hostname extraction [P1]

**Given** `outcalld` is running with the proxy listening
**And** the rule engine allows `network.hostname == "cdn.example.com"`
**When** the agent sends a `CONNECT cdn.example.com:443` request
**And** the TLS ClientHello contains SNI `cdn.example.com`
**Then** the proxy uses the SNI hostname for rule evaluation
**And** the extracted SNI matches the CONNECT hostname
**And** the connection is allowed.

### S006-AS-006 Rule engine verdict with CEL context [P1]

**Given** `outcalld` is running with the proxy listening
**And** the rule engine has a rule: `network.hostname.endsWith(".internal.corp") && http.method == "GET"`
**When** the agent makes `GET http://api.internal.corp/status`
**Then** the proxy populates CEL context:
  - `network.hostname` = `"api.internal.corp"`
  - `http.method` = `"GET"`
  - `http.path` = `"/status"`
**And** the rule engine evaluates and returns ALLOW.

### S006-AS-007 Connection timeout [P2]

**Given** `outcalld` is running with its 10-second upstream timeout
**When** the agent makes an HTTP request to a host where the upstream does not respond within 10 seconds
**Then** the proxy returns HTTP 504 Gateway Timeout to the agent.

### S006-AS-008 Max connections reached [P2]

**Given** `outcalld` is running with its 1024-connection limit
**And** 1024 connections are currently active
**When** a new agent connection arrives
**Then** the proxy returns HTTP 503 Service Unavailable
**And** the new connection is closed.

### S006-AS-009 Proxy startup and shutdown [P1]

**Given** `outcalld` is starting up
**When** the daemon initializes
**Then** the proxy task starts and begins listening on the configured address
**And** the proxy logs the listen address at `info` level.

**Given** `outcalld` is shutting down
**And** 3 active tunnels exist
**When** the daemon receives a shutdown signal
**Then** the proxy stops accepting new connections
**And** the proxy waits up to the grace period for active tunnels to complete
**And** after the grace period, remaining tunnels are dropped
**And** the proxy task exits cleanly.

### S006-AS-010 No SNI in ClientHello [P2]

**Given** `outcalld` is running with the proxy listening
**And** the rule engine allows `network.hostname == "10.200.5.10"` and explicitly opts into private upstream addresses
**When** the agent sends `CONNECT 10.200.5.10:443`
**And** the TLS ClientHello does not contain an SNI extension
**Then** the proxy falls back to using `10.200.5.10` from the CONNECT line
**And** the proxy evaluates with `network.hostname = "10.200.5.10"`
**And** the rule engine returns ALLOW
**And** the tunnel is established.

### S006-AS-011 Multiple agents concurrent [P1]

**Given** `outcalld` is running with the proxy listening
**And** 10 agent containers are running on the network
**When** all 10 agents make simultaneous HTTP requests to different allowed hosts
**Then** all 10 requests are evaluated independently
**And** all 10 requests are forwarded to their respective upstream hosts
**And** all 10 agents receive their responses.

### S006-AS-012 Upstream unreachable [P2]

**Given** `outcalld` is running with the proxy listening
**And** the rule engine allows `network.hostname == "down.example.com"`
**When** the agent makes an HTTP request to `http://down.example.com/api`
**And** the upstream server refuses the connection
**Then** the proxy returns HTTP 502 Bad Gateway to the agent
**And** the response body indicates the upstream was unreachable.

### S006-AS-013 Blocked request logging [P2]

**Given** `outcalld` is running with the proxy listening
**When** the agent makes an HTTP request that is blocked by the rule engine
**Then** the proxy logs a `warn` level message containing:
  - source IP of the agent container
  - target hostname
  - HTTP method
  - block reason from the rule engine.
**And** query strings, headers, bodies, and credentials are not logged.
