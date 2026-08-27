# S007 Acceptance Scenarios

### S007-AS-001 Allowed query resolved [P1]

**Given** `outcalld` is running with the bridge up and DNS filter active
**And** a rule exists: `condition: dns.query == "api.github.com"`, `action: allow`
**When** a container on the outcall network sends a DNS query for `A api.github.com`
**Then** `outcalld` evaluates the query against the rule engine
**And** the rule engine returns ALLOW
**And** `outcalld` forwards the query to the upstream resolver
**And** the upstream response (with the real IP address) is returned to the container
**And** a debug-level log entry records the query, decision, matched rule, and upstream latency.

### S007-AS-002 Blocked query returns NXDOMAIN [P1]

**Given** `outcalld` is running with the bridge up and DNS filter active
**And** a rule exists: `condition: dns.query.endsWith(".evil.com")`, `action: block`
**When** a container sends a DNS query for `A malware.evil.com`
**Then** `outcalld` evaluates the query against the rule engine
**And** the rule engine returns BLOCK
**And** `outcalld` returns an NXDOMAIN response with an SOA record in the authority section
**And** the container receives NXDOMAIN and does not learn the real IP
**And** a debug-level log entry records the query, decision, and matched rule.

### S007-AS-003 No matching rule defaults to block [P1]

**Given** `outcalld` is running with the bridge up and DNS filter active
**And** no rule matches the hostname `random-unknown-site.com`
**When** a container sends a DNS query for `A random-unknown-site.com`
**Then** the rule engine returns BLOCK (default policy)
**And** `outcalld` returns NXDOMAIN
**And** the log entry shows `matched_rule: null` and `decision: block`.

### S007-AS-004 DNS server starts with bridge [P1]

**Given** `outcalld` is running but the bridge is not yet up
**When** the user runs `outcall bridge up`
**And** the bridge comes up with gateway `10.200.0.1`
**Then** the DNS server binds to `10.200.0.1:53` on both UDP and TCP
**And** `outcall dns status` shows `running: true` with the correct listen address
**And** an info-level log entry records the DNS server startup.

### S007-AS-005 Graceful shutdown drains queries [P1]

**Given** `outcalld` is running with the DNS filter active
**And** a DNS query is currently being forwarded to an upstream
**When** `outcalld` receives a shutdown signal
**Then** the DNS server stops accepting new queries
**And** the in-flight query completes (or times out within 5 seconds)
**And** all UDP and TCP sockets are closed
**And** an info-level log entry records the DNS server shutdown.

### S007-AS-006 Container resolv.conf points at outcalld [P1]

**Given** `outcalld` is running with bridge gateway `10.200.0.1`
**When** a container is started on an outcall network
**Then** the container's `/etc/resolv.conf` contains `nameserver 10.200.0.1`
**And** no other `nameserver` lines are present
**And** `options ndots:0` is set
**And** DNS queries from the container go through `outcalld`.

### S007-AS-007 Upstream failover on timeout [P2]

**Given** `outcalld` is configured with `--dns-upstream 10.0.0.1:53,8.8.8.8:53`
**And** the first upstream (`10.0.0.1`) is unreachable
**When** a container sends an allowed DNS query
**Then** `outcalld` attempts the first upstream
**And** after `DNS_UPSTREAM_TIMEOUT_MS` elapses, falls back to the second upstream (`8.8.8.8`)
**And** the response from the second upstream is returned to the container
**And** a warn-level log entry records the first upstream's failure.

### S007-AS-008 Cached response served [P2]

**Given** `outcalld` has previously resolved `A api.github.com` and cached the response
**And** the cache entry has not expired
**When** a container sends another DNS query for `A api.github.com`
**Then** `outcalld` evaluates the query against the rule engine (cache does not bypass policy)
**And** the rule engine returns ALLOW
**And** the cached response is returned without contacting the upstream
**And** the TTL values in the response are decremented to reflect elapsed time
**And** the log entry shows `cached: true`.

### S007-AS-009 Cache invalidated on rule reload [P2]

**Given** `outcalld` has cached DNS responses for several hostnames
**When** the rule engine reloads rules (via API or file watch)
**Then** the entire DNS cache is flushed
**And** subsequent queries are forwarded to upstream resolvers
**And** an info-level log entry records the cache flush with the number of entries cleared.

### S007-AS-010 TCP fallback for large responses [P1]

**Given** `outcalld` is running with the DNS filter active
**When** a container sends a UDP DNS query for a hostname whose response exceeds 512 bytes
**And** the upstream returns a truncated response (TC bit set)
**Then** `outcalld` retries the query to the upstream over TCP
**And** the full response is returned to the container over TCP.

### S007-AS-011 CLI DNS filter status [P1]

**Given** `outcalld` is running with the DNS filter active
**When** the user runs `outcall dns status`
**Then** the CLI prints the DNS filter status including listen address, upstreams, cache entries, and query counters
**And** the command exits with code 0.

### S007-AS-012 CLI DNS test query [P1]

**Given** `outcalld` is running with the DNS filter active
**When** the user runs `outcall dns test api.github.com`
**Then** `outcalld` evaluates the hostname against the rule engine (without actually sending a DNS query)
**And** the CLI prints the decision (allow/block) and the matched rule
**And** the command exits with code 0.

### S007-AS-013 Daemon not running (CLI) [P1]

**Given** `outcalld` is not running
**When** the user runs any `outcall dns` subcommand
**Then** the CLI prints `Error: cannot connect to outcalld at <socket> -- is it running?`
**And** the command exits with code 1.

### S007-AS-014 DNSSEC records passed through [P2]

**Given** `outcalld` is running with the DNS filter active
**And** a query is allowed by the rule engine
**When** a container sends a DNS query with the DO (DNSSEC OK) bit set
**Then** `outcalld` forwards the query to the upstream with the DO bit preserved
**And** the upstream response including RRSIG, DNSKEY, DS, NSEC, or NSEC3 records is returned to the container unmodified.

### S007-AS-015 Multiple query types handled [P1]

**Given** `outcalld` is running with the DNS filter active
**And** a rule allows `dns.query == "mail.example.com"`
**When** a container sends an `MX` query for `mail.example.com`
**Then** `outcalld` evaluates with `dns.record_type == "MX"`
**And** the query is forwarded to the upstream
**And** the MX response is returned to the container.

### S007-AS-016 Direct-IP grants follow DNS TTL [P1]

**Given** an IPv4 managed container resolves an allowed `direct_ip` hostname
**And** the permitted A answers have a minimum TTL of 60 seconds
**When** `outcalld` creates the corresponding destination-port grants
**Then** each grant reports no more than 60 seconds remaining
**And** AAAA answers create no grant for the IPv4 source
**And** the nftables handles are removed within one sweep interval after expiry.
