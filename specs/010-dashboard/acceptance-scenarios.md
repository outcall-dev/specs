# S010 Acceptance Scenarios

### S010-AS-001 Dashboard loads in browser [P2]

**Given** `outcalld` is running
**When** the operator runs `outcall ui` and opens the printed loopback URL
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

### S010-AS-004 Authenticated local bridge [P1]

**Given** `outcalld` is running on its host Unix socket
**When** the operator runs `outcall ui`
**Then** the CLI binds only to `127.0.0.1`
**And** opens a URL containing a random token in the fragment
**And** the dashboard clears the fragment and sends the token as `X-Outcall-Token`
**And** API requests without that token are rejected.

### S010-AS-005 Rebinding and request-smuggling inputs rejected [P1]

**Given** the local dashboard bridge is running
**When** a request has a non-loopback `Host`, cross-origin `Origin`, duplicate security header, transfer encoding, or body bytes beyond its declared length
**Then** the bridge rejects it before connecting to the daemon socket.

### S010-AS-006 Token arrives after tokenless load [P1]

**Given** the dashboard document was loaded without a URL fragment
**And** it has made no API requests
**When** the same document receives the valid session token through a fragment-only navigation
**Then** the fragment is removed from the address bar
**And** authenticated polling starts exactly once
**And** the dashboard reaches the connected state without a full reload.
