# S001 Acceptance Scenarios

### S001-AS-001 Bridge up: happy path [P1]

**Given** `outcalld` is running on Linux with `CAP_NET_ADMIN`
**And** no bridge named `outcall0` exists
**When** `outcalld` starts (or `outcall bridge up` is called)
**Then** a bridge interface `outcall0` is created and brought up
**And** the `inet outcall` nftables table is created with drop-all forward rules
**And** `outcall bridge status` reports `up` and `nftables: active`.

### S001-AS-002 Bridge up: idempotent re-up [P1]

**Given** the bridge `outcall0` is already up with nftables rules active
**When** `outcall bridge up` is called again
**Then** the daemon attaches to the existing bridge (does not error)
**And** nftables rules are reapplied (clean-slate)
**And** `outcall bridge status` still reports `up`.

### S001-AS-003 Status: bridge is up [P1]

**Given** the bridge is up and nftables rules are active
**When** `outcall bridge status` is called
**Then** the CLI prints the bridge name, status `up`, interface index, and `nftables: active`.

### S001-AS-004 Status: bridge is down [P1]

**Given** the bridge has been torn down (or was never created)
**When** `outcall bridge status` is called
**Then** the CLI prints the bridge name, status `down`, and `nftables: inactive`.

### S001-AS-005 Teardown: happy path [P1]

**Given** the bridge is up with nftables rules active
**When** `outcall bridge down` is called
**Then** the nftables table is deleted
**And** the bridge interface is brought down and removed
**And** `ip link show outcall0` fails (interface gone)
**And** `nft list table inet outcall` fails (table gone).

### S001-AS-006 Daemon shutdown tears down [P1]

**Given** `outcalld` is running with the bridge up
**When** `outcalld` receives SIGINT (Ctrl-C)
**Then** the bridge and nftables rules are torn down before the process exits
**And** the unix socket file is removed.

### S001-AS-007 Bridge already exists: attach [P1]

**Given** a bridge named `outcall0` already exists (created by Docker or another process)
**When** `outcalld` starts
**Then** it attaches to the existing bridge (reuses the interface index)
**And** applies nftables rules normally
**And** does not error.

### S001-AS-008 CLI: bridge status [P1]

**Given** `outcalld` is running
**When** the user runs `outcall bridge status`
**Then** the CLI connects to the unix socket, sends `GET /api/v1/bridge`, and prints the status.

### S001-AS-009 CLI: bridge up [P1]

**Given** `outcalld` is running
**When** the user runs `outcall bridge up`
**Then** the CLI sends `POST /api/v1/bridge/up` and prints `Bridge is up.` on success.

### S001-AS-010 CLI: bridge down [P1]

**Given** `outcalld` is running
**When** the user runs `outcall bridge down`
**Then** the CLI sends `POST /api/v1/bridge/down` and prints `Bridge is down.` on success.
