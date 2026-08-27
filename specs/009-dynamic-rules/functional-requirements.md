# S009 Functional Requirements

### Rule insertion

S009-FR-001 [P1] `outcalld` **MUST** insert nftables allow rules into the `inet outcall forward` chain when the rule engine (S003) returns an ALLOW verdict for a specific traffic flow.

S009-FR-002 [P1] `outcalld` **MUST** remove the corresponding nftables rule when an allow verdict is revoked or expires.

S009-FR-003 [P1] Each dynamic rule **MUST** be keyed to a specific combination of:
S009-FR-003.a Source container — tracked by container name (stable identifier) but matched in nftables by the container's current IP address on the outcall network
S009-FR-003.b Destination (hostname, IP, or CIDR)
S009-FR-003.c Protocol and port (optional — if omitted, all protocols allowed to that destination)

S009-FR-004 [P1] When a container terminates for any reason (explicit stop, remove, OOM kill, crash), `outcalld` **MUST** remove all dynamic nftables rules associated with that container. `outcalld` **MUST** subscribe to Docker container death events (not just explicit stop/remove API calls) to ensure rule cleanup regardless of termination reason.

### Base ruleset integrity

S009-FR-005 [P1] Dynamic rules **MUST** be inserted BEFORE the base drop rules in the chain (using `nft insert` or rule position). The base drop rules from S001 **MUST NOT** be modified or removed by the dynamic rule system.

### Rule tracking

S009-FR-006 [P2] `outcalld` **SHOULD** maintain an in-memory map of active dynamic rules (container → list of nft rule handles) for inspection.

S009-FR-007 [P1] `outcalld` **MUST** track the nftables rule handle returned by each insert so that specific rules can be removed without flushing the entire chain.

S009-FR-008 [P1] Rule insertions and removals **MUST** be serialized (via a Tokio mutex or channel) to prevent race conditions when multiple containers are being managed concurrently.

### Lifecycle

S009-FR-009 [P2] `outcalld` **SHOULD** provide a "flush all dynamic rules" operation that removes all inserted allow rules while preserving the base drop rules.

S009-FR-010 [P1] Dynamic rules **MUST NOT** survive a daemon restart. On startup, `outcalld` applies only the base ruleset (S001). Any previously active dynamic rules are gone — containers must re-request permission.

### Default policy

S009-FR-011 [P1] In the absence of a dynamic allow rule for a given traffic flow, the flow is dropped by the base nftables ruleset (S001-FR-005). Dynamic rules only create exceptions to the default BLOCK policy — they never create a permissive default.

S009-FR-012 [P1] A dynamic rule request for an IP currently owned by a managed container **MUST** name that exact container. Docker identity lookup errors **MUST** fail closed. The trusted host operator API **MAY** pre-stage a rule for an address that Docker verifies is currently unassigned; container-facing APIs do not expose this capability.

S009-FR-013 [P1] Source addresses **MUST** be valid IP addresses. Destination literals **MUST** be valid canonical IP addresses or CIDRs. A port **MUST NOT** be accepted without an explicit `tcp` or `udp` protocol. Hostname resolution and every `nft` command **MUST** have bounded deadlines.

S009-FR-014 [P1] If deletion of an individual dynamic rule fails, `outcalld` **MUST** immediately restore the complete base policy, removing every dynamic allow rule. It **MUST** clear its active-rule map only after either individual deletion or the base-policy reset succeeds. If both fail, the operation **MUST** return an error and retain the tracked state for operator visibility.

S009-FR-015 [P1] A dynamic rule request **MAY** include `expires_in_secs`. When present, it **MUST** be between 1 and `MAX_DYNAMIC_RULE_TTL_SECS` (86,400) inclusive. `outcalld` **MUST** remove the rule no later than one expiry sweep interval after its deadline. Omitting the field creates an explicit persistent grant that remains subject to container cleanup, flush, policy reset, and daemon restart.

S009-FR-016 [P1] Re-inserting an equivalent temporary managed rule **MUST** renew its deadline without adding another nftables rule. A DNS-managed renewal **MUST NOT** narrow a persistent host-operator grant. A trusted host-operator request **MUST** be authoritative and may change an equivalent rule between temporary and persistent forms.
