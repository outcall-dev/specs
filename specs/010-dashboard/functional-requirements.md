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

### Local browser bridge

S010-FR-011 [P1] `outcall ui` **MUST** expose the dashboard only on an explicit `127.0.0.1` TCP listener and forward validated requests to the host Unix socket. It **MUST NOT** bind a wildcard or non-loopback address.

S010-FR-012 [P1] Each bridge process **MUST** generate a cryptographically random 256-bit session token. The launch URL **MUST** carry it in a URL fragment, the dashboard **MUST** remove that fragment from the address bar, and API requests **MUST** send it in `X-Outcall-Token`. The bridge **MUST** strip that header before forwarding.

S010-FR-013 [P1] The bridge **MUST** validate an exact loopback `Host`, validate `Origin` when present, reject duplicate security headers, accept only bounded HTTP/1.1 origin-form requests with unambiguous `Content-Length` framing, and force the upstream connection closed after one request.

S010-FR-014 [P1] Header size, body size, connection duration, and concurrent bridge connections **MUST** be bounded. Exceeding a bound **MUST** return an error or close the individual connection without stopping the bridge.

S010-FR-015 [P1] The dashboard **MUST** accept its session token from either the
initial URL fragment or a later same-document `hashchange`, clear the fragment
from browser history, make no API request before a token exists, and start at
most one refresh interval.

S010-FR-016 [P2] The dashboard **MUST** remain usable at desktop and mobile
viewport widths. Wide tables **MUST** scroll inside their own view and **MUST NOT**
create document-level horizontal overflow; empty states and controls
**MUST NOT** overlap or clip.
