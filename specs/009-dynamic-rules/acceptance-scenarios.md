# S009 Acceptance Scenarios

### S009-AS-001 Allow rule inserted, traffic flows [P1]

**Given** the bridge is up with base drop-all rules active
**And** a container `my-agent` is on the outcall network
**When** the rule engine returns ALLOW for `my-agent` → `github.com:443`
**Then** `outcalld` inserts an nftables rule allowing that traffic
**And** the container can reach `github.com:443`
**And** all other outbound traffic from `my-agent` remains blocked.

### S009-AS-002 Rule removed, traffic re-blocked [P1]

**Given** `my-agent` has an active allow rule for `github.com:443`
**When** the rule is revoked (policy change, timeout, or explicit removal)
**Then** `outcalld` removes the nftables rule
**And** `my-agent` can no longer reach `github.com:443`.

### S009-AS-003 Container stopped, all rules removed [P1]

**Given** `my-agent` has three active allow rules (github, pypi, apt repo)
**When** `my-agent` is stopped or removed
**Then** all three nftables rules are removed
**And** `nft list chain inet outcall forward` shows only the base rules.

### S009-AS-004 List active rules [P2]

**Given** two containers have active dynamic rules
**When** the host operator queries active rules (via API or CLI)
**Then** the response lists each rule with container name, destination, and protocol.

### S009-AS-005 Base rules still apply [P1]

**Given** `my-agent` has an allow rule for `github.com:443`
**When** `my-agent` tries to reach `evil.com:80` (no allow rule)
**Then** the traffic is blocked by the base drop rules
**And** the dynamic allow rule for github does not affect other destinations.
