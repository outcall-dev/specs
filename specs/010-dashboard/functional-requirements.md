# S010 Functional Requirements

### Serving

S010-FR-001 [P2] The dashboard **MUST** be built as static HTML/JS/CSS assets embedded in the `outcall-ui` crate via `rust-embed`, compiled into the `outcalld` binary.

S010-FR-002 [P2] The dashboard **MUST** be served on the host unix socket at `/` (or `/ui/`). The same axum router that serves the API **MUST** serve the dashboard assets.

S010-FR-009 [P2] The dashboard **MUST NOT** be accessible from agent containers. It is served on the host socket only.

### Pages

S010-FR-003 [P2] The dashboard **MUST** display a system overview: bridge status, number of networks, number of containers, number of active rules.

S010-FR-004 [P2] The dashboard **MUST** display a network listing: name, subnet, gateway, container count for each outcall-managed network.

S010-FR-005 [P2] The dashboard **MUST** display a container listing: name, network, IP address, number of active allow rules.

S010-FR-006 [P2] The dashboard **MUST** display active dynamic rules (S009): container, destination, port, inserted timestamp.

S010-FR-007 [P2] The dashboard **MUST** display the rule request queue (S004) with approve/reject buttons for pending requests.

S010-FR-008 [P3] The dashboard **MAY** display a live traffic log showing recent allowed and blocked requests.

### Updates

S010-FR-010 [P3] The dashboard **MAY** use WebSocket or polling to auto-refresh state without manual page reload.
