# S010 Acceptance Scenarios

### S010-AS-001 Dashboard loads in browser [P2]

**Given** `outcalld` is running
**When** the operator opens `http://localhost/ui/` (via socat or SSH tunnel to the unix socket)
**Then** the dashboard loads and displays the system overview.

### S010-AS-002 Bridge status displayed [P2]

**Given** the bridge is up with nftables active
**When** the operator views the dashboard
**Then** the bridge status section shows name, status `up`, and nftables `active`.

### S010-AS-003 Approve rule request [P2]

**Given** an agent submitted a rule request that is pending
**When** the operator clicks "Approve" on the dashboard
**Then** the request status changes to approved
**And** the corresponding allow rule is created.
