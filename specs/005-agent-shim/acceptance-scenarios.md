# S005 Acceptance Scenarios

## S005-AS-001 Check-In Happy Path [P1]

**Given** helper mounts are enabled and the agent socket is reachable
**When** `outcall exec true` starts
**Then** the shim checks in, receives daemon-derived identity and a session token,
starts its heartbeat, requests a verdict, and executes only after an allow.

## S005-AS-002 Socket Missing [P1]

**Given** `/run/outcall/agent.sock` is absent
**When** a mediated action starts
**Then** no child is spawned and the shim exits 5 with a stderr diagnostic.

## S005-AS-003 Command Allowed [P1]

**Given** policy allows `git status`
**When** the caller runs `outcall exec git status`
**Then** the exact `git`, `status` argument vector is evaluated and executed.

## S005-AS-004 Command Blocked [P1]

**Given** policy denies the requested command
**When** the caller invokes it through the shim
**Then** no child is spawned, the reason is printed to stderr, and the shim exits 1.

## S005-AS-005 Network Probe [P1]

**Given** a caller runs `outcall fetch https://api.openai.com`
**When** policy evaluation completes
**Then** the shim returns allow or deny without itself opening the URL. A real
connection is independently constrained by the managed bridge and proxy.

## S005-AS-006 File Probe [P1]

**Given** a caller runs `outcall file /workspace/config.yaml`
**When** policy evaluation completes
**Then** the shim returns allow or deny without reading the file.

## S005-AS-007 Daemon Loss During Child [P1]

**Given** an allowed long-running child and active heartbeat
**When** daemon reachability fails
**Then** the child is killed and reaped and the shim exits 5 within one heartbeat
interval plus the configured request timeout.

## S005-AS-008 Request Timeout [P1]

**Given** the daemon accepts a request but does not answer
**When** `OUTCALL_TIMEOUT_SECS` expires
**Then** no new child starts and the shim exits 5.

## S005-AS-009 Graceful SIGTERM [P2]

**Given** a request or child is in flight
**When** the shim receives SIGTERM
**Then** it begins no new work, completes the in-flight work, stops heartbeat,
and exits 0.

## S005-AS-010 Optional Mount Immutability [P1]

**Given** daemon container creation enables helper mounts
**Then** `/usr/local/bin/outcall` is a read-only bind mount and the agent socket
is the only daemon control surface mounted for the shim.
