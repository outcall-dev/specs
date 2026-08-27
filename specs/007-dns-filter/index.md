# S007: DNS Filter

| Field | Value |
|-------|-------|
| Spec | S007 |
| Feature | DNS Filter |
| Date | 2026-04-21 |
| Status | Implemented |
| Author | @marktopper |

## Overview

The DNS filter is an application-layer name resolution gateway that prevents
agent containers from resolving hostnames that policy does not permit. It runs
as a Tokio task inside `outcalld`, listening for DNS queries on the bridge IP
(e.g., `10.200.0.1:53`). Agent containers have their `/etc/resolv.conf`
configured to use this address as their sole nameserver.

When a query arrives, the filter extracts the hostname and query type, builds a
`DnsContext` (S003), and evaluates it against the rule engine. Allowed queries
are forwarded to an upstream resolver and the response is returned to the agent.
Blocked queries receive an NXDOMAIN response -- the agent never learns the real
IP address.

Before evaluating policy, the filter requires the source IP to map to a
currently managed Outcall container. Unknown peers receive DNS REFUSED. Allowed
answers are filtered through the shared restricted-address policy on every
cache hit and miss; private targets require an explicit rule opt-in.

This is a complementary layer to the nftables bridge rules (S001). nftables
blocks at L3/L4 by dropping packets to disallowed IPs and ports. The DNS filter
blocks at the application layer by preventing name resolution entirely. Together
they form defense in depth: even if an agent hardcodes an IP address, nftables
catches it; even if nftables rules are broad, DNS filtering narrows what the
agent can discover.

### How it works

1. `outcalld` starts a DNS server on the bridge gateway IP, port 53 (UDP and TCP)
2. Agent containers have `/etc/resolv.conf` pointing at this DNS server
3. Agent sends a DNS query (e.g., `A api.github.com`)
4. `outcalld` extracts `dns.query` and `dns.record_type` from the query
5. The rule engine (S003) evaluates the request
6. **ALLOW** -- forward the query to the configured upstream resolver, return the response
   - If the matched rule sets `egress.mode: direct_ip`, `outcalld` also inserts scoped nftables allow rules for resolved IPv4 targets and configured ports.
   - If the matched rule sets `egress.mode: proxy`, no L3/L4 holes are opened; access is expected through the L7 proxy path.
7. **BLOCK** -- return NXDOMAIN with SOA in the authority section

### Upstream resolution

`outcalld` supports one or more upstream DNS resolvers. The default upstream is
the host's `/etc/resolv.conf` nameservers, but operators can override this via
`--dns-upstream`. When multiple upstreams are configured, `outcalld` tries them
in order, falling back to the next on timeout or error.

### Caching

The DNS filter implements a response cache for allowed queries. Cached entries
respect the minimum TTL from the upstream response, capped at a configurable
maximum. The cache is keyed on `(hostname, record_type)`. Cache entries are
invalidated on rule reload (S003) to ensure policy changes take effect
immediately.

## User Scenarios

S007-US-001 [P1] As a host operator, I want all DNS queries from agent containers to pass through outcalld so that name resolution is governed by policy.

S007-US-002 [P1] As a host operator, I want blocked hostnames to return NXDOMAIN so that agents cannot discover IP addresses for disallowed services.

S007-US-003 [P1] As a host operator, I want allowed DNS queries forwarded to upstream resolvers so that agents can reach permitted services.

S007-US-004 [P2] As a host operator, I want to configure upstream DNS resolvers so that I control where queries are forwarded.

S007-US-005 [P2] As a host operator, I want DNS responses cached so that repeated lookups for allowed hostnames are fast and reduce upstream load.

S007-US-006 [P1] As a host operator, I want DNS query decisions logged so that I can audit what agents attempted to resolve.

S007-US-007 [P2] As a host operator, I want to check DNS filter status so that I can verify it is running and see its configuration.

## Requirements Summary

| ID | Type | Priority | Title | Status |
|----|------|----------|-------|--------|
| S007-FR-001 | Functional | P1 | DNS server on bridge IP | Implemented |
| S007-FR-002 | Functional | P1 | UDP and TCP listeners | Implemented |
| S007-FR-003 | Functional | P1 | Tokio task lifecycle | Implemented |
| S007-FR-004 | Functional | P1 | Bridge-up prerequisite | Implemented |
| S007-FR-005 | Functional | P1 | Graceful shutdown | Implemented |
| S007-FR-006 | Functional | P1 | Container resolv.conf injection | Implemented |
| S007-FR-007 | Functional | P1 | Query interception and parsing | Implemented |
| S007-FR-008 | Functional | P1 | Rule engine evaluation | Implemented |
| S007-FR-009 | Functional | P1 | CEL context variables | Implemented |
| S007-FR-010 | Functional | P1 | NXDOMAIN for blocked queries | Implemented |
| S007-FR-011 | Functional | P1 | Upstream forwarding for allowed queries | Implemented |
| S007-FR-012 | Functional | P1 | Upstream resolver configuration | Implemented |
| S007-FR-013 | Functional | P1 | Default upstream from host resolv.conf | Implemented |
| S007-FR-014 | Functional | P2 | Multiple upstream resolvers | Implemented |
| S007-FR-015 | Functional | P2 | Upstream failover | Draft |
| S007-FR-016 | Functional | P2 | Response caching | Implemented |
| S007-FR-017 | Functional | P2 | Cache TTL handling | Implemented |
| S007-FR-018 | Functional | P2 | Cache invalidation on rule reload | Implemented |
| S007-FR-019 | Functional | P2 | Cache size limit | Implemented |
| S007-FR-020 | Functional | P1 | DNS over TCP fallback | Draft |
| S007-FR-021 | Functional | P2 | DNSSEC pass-through | Draft |
| S007-FR-022 | Functional | P1 | Query logging | Implemented |
| S007-FR-023 | Functional | P1 | Performance latency budget | Draft |
| S007-FR-024 | Functional | P1 | hickory-dns implementation | Implemented |
| S007-FR-025 | Functional | P1 | Structured logging | Implemented |
| S007-FR-026 | Functional | P1 | Typed errors | Draft |
| S007-FR-027 | Functional | P1 | Host API endpoints | Implemented |
| S007-FR-028 | Functional | P1 | CLI subcommands | Implemented |
| S007-FR-029 | Functional | P2 | Configurable listen port | Implemented |
| S007-FR-030 | Functional | P2 | Cache statistics endpoint | Implemented |
| S007-FR-031 | Functional | P3 | DNS query metrics | Draft |
| S007-FR-032 | Functional | P1 | Fail-closed on rule engine error | Implemented |
| S007-FR-033 | Functional | P2 | mDNS (.local) blocked | Implemented |
| S007-FR-034 | Functional | P2 | Restricted-address filtering | Implemented |
| S007-FR-035 | Functional | P1 | Rule-configurable egress mode | Implemented |
| S007-FR-036 | Functional | P1 | Proxy mode opens no direct grant | Implemented |
| S007-FR-037 | Functional | P1 | Same-family direct-IP grants | Implemented |
| S007-FR-038 | Functional | P2 | Default direct-IP ports | Implemented |
| S007-FR-039 | Functional | P1 | Managed peer identity required | Implemented |
| S007-FR-040 | Functional | P1 | DNS-TTL-bound direct grants | Implemented |
| S007-AS-001 | Acceptance | P1 | Allowed query resolved | Implemented |
| S007-AS-002 | Acceptance | P1 | Blocked query returns NXDOMAIN | Implemented |
| S007-AS-003 | Acceptance | P1 | No matching rule defaults to block | Implemented |
| S007-AS-004 | Acceptance | P1 | DNS server starts after bridge | Implemented |
| S007-AS-005 | Acceptance | P1 | Graceful shutdown drains queries | Draft |
| S007-AS-006 | Acceptance | P1 | Container resolv.conf points at outcalld | Implemented |
| S007-AS-007 | Acceptance | P2 | Upstream failover on timeout | Draft |
| S007-AS-008 | Acceptance | P2 | Cached response served | Implemented |
| S007-AS-009 | Acceptance | P2 | Cache invalidated on rule reload | Implemented |
| S007-AS-010 | Acceptance | P1 | TCP fallback for large responses | Draft |
| S007-AS-011 | Acceptance | P1 | CLI DNS filter status | Implemented |
| S007-AS-012 | Acceptance | P1 | CLI DNS filter test query | Implemented |
| S007-AS-013 | Acceptance | P1 | Daemon not running (CLI) | Implemented |
| S007-AS-014 | Acceptance | P2 | DNSSEC records passed through | Draft |
| S007-AS-015 | Acceptance | P1 | Multiple query types handled | Implemented |
| S007-AS-016 | Acceptance | P1 | Direct-IP grants follow DNS TTL | Implemented |
| S007-IF-001 | Interface | P1 | GET /api/v1/dns | Implemented |
| S007-IF-002 | Interface | P2 | GET /api/v1/dns/cache | Implemented |
| S007-IF-003 | Interface | P2 | POST /api/v1/dns/cache/flush | Implemented |
| S007-IF-004 | Interface | P1 | CLI commands | Implemented |
| S007-IF-005 | Interface | P1 | CLI output format | Implemented |
| S007-IF-006 | Interface | P1 | DNS wire protocol (RFC 1035) | Implemented |
| S007-IF-007 | Interface | P1 | resolv.conf format | Implemented |
| S007-IF-008 | Interface | P1 | DNS rule egress config | Implemented |
| S007-EC-001 | Edge Case | P1 | Bridge not up | Implemented |
| S007-EC-002 | Edge Case | P1 | All upstreams unreachable | Implemented |
| S007-EC-003 | Edge Case | P1 | Upstream timeout | Implemented |
| S007-EC-004 | Edge Case | P2 | Malformed DNS query | Implemented |
| S007-EC-005 | Edge Case | P1 | Rule engine unavailable | Implemented |
| S007-EC-006 | Edge Case | P2 | Query for outcalld's own address | Implemented |
| S007-EC-007 | Edge Case | P2 | Cache full | Implemented |
| S007-EC-008 | Edge Case | P1 | Port 53 already in use | Implemented |
| S007-EC-009 | Edge Case | P2 | Extremely long hostname | Implemented |
| S007-EC-010 | Edge Case | P2 | Rapid duplicate queries | Draft |
| S007-EC-011 | Edge Case | P2 | EDNS0 options | Implemented |
| S007-EC-012 | Edge Case | P1 | Daemon shutdown mid-query | Implemented |
| S007-EC-013 | Edge Case | P2 | Upstream returns SERVFAIL | Implemented |
| S007-EC-014 | Edge Case | P2 | PTR / reverse DNS queries | Implemented |
| S007-EC-015 | Edge Case | P3 | DNS amplification prevention | Implemented |
| S007-EC-016 | Edge Case | P1 | Cached restricted address | Implemented |
| S007-EC-017 | Edge Case | P1 | Mixed-family direct answer | Implemented |
| S007-SC-001 | Success | P1 | DNS server binds on bridge IP | Implemented |
| S007-SC-002 | Success | P1 | Allowed query returns upstream answer | Implemented |
| S007-SC-003 | Success | P1 | Blocked query returns NXDOMAIN | Implemented |
| S007-SC-004 | Success | P1 | Default block on no matching rule | Implemented |
| S007-SC-005 | Success | P1 | Latency under budget | Draft |
| S007-SC-006 | Success | P1 | Container resolv.conf verified | Implemented |
| S007-SC-007 | Success | P2 | Cache hit avoids upstream call | Implemented |
| S007-SC-008 | Success | P1 | Audit log entries for all queries | Implemented |
| S007-SC-009 | Success | P1 | Clean shutdown (no leaked sockets) | Implemented |
| S007-SC-010 | Success | P1 | Existing bridge/network/rule commands unaffected | Implemented |

## Out of Scope

- **DNS-over-HTTPS (DoH) or DNS-over-TLS (DoT)** -- agents query plain DNS on port 53; encrypted DNS from agents would bypass the filter and is blocked by nftables
- **Recursive resolution** -- outcalld forwards to upstream resolvers, it does not perform iterative resolution
- **Zone hosting / authoritative DNS** -- outcalld is not a DNS server for any zone; it is a filtering forwarder
- **DNSSEC validation** -- outcalld passes DNSSEC records through but does not validate signatures itself
- **IPv6 AAAA filtering as separate policy** -- AAAA queries are evaluated by the same rule engine as A queries
- **Per-container DNS policy** -- all containers on the bridge share the same rule set
- **Custom DNS records / split-horizon** -- outcalld does not synthesize records beyond NXDOMAIN
- **GUI for DNS management** -- CLI and API only

## Cross-Spec Dependencies

- **Depends on:** [S001](../001-bridge-management/index.md) (bridge must be up; DNS server binds to bridge gateway IP -- S007-FR-004)
- **Depends on:** [S002](../002-network-management/index.md) (network provides the bridge gateway IP that the DNS server listens on; container resolv.conf points here)
- **Depends on:** [S003](../003-rule-engine/index.md) (rule engine evaluates `dns.query` and `dns.record_type` context variables -- S007-FR-008)
- **Complements:** [S006](../006-http-proxy/index.md) (HTTP proxy handles L7 HTTP inspection; DNS filter prevents resolution of blocked hostnames before HTTP is even attempted)

## Security Guidance

- **Recommended (best approach):** use `egress.mode: proxy` for internet hostnames, especially CDN/shared-IP endpoints. This keeps policy at hostname/SNI granularity and avoids broad IP-level access.
- **Use with caution:** `egress.mode: direct_ip` opens L3/L4 rules to resolved IPs, which can allow unrelated tenants on shared IP infrastructure.

## Shared Types (outcall-api)

### Constants

```rust
pub const DNS_DEFAULT_PORT: u16 = 53;
pub const DNS_UPSTREAM_TIMEOUT_MS: u64 = 5000;
pub const DNS_CACHE_MAX_ENTRIES: usize = 10_000;
pub const DNS_CACHE_MAX_TTL_SECS: u32 = 300;
pub const DNS_QUERY_LATENCY_BUDGET_MS: u64 = 10;
pub const DNS_TCP_TIMEOUT_MS: u64 = 10_000;
```

### Types

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DnsFilterStatus {
    pub running: bool,
    pub listen_address: String,
    pub listen_port: u16,
    pub upstreams: Vec<String>,
    pub cache_entries: usize,
    pub queries_total: u64,
    pub queries_allowed: u64,
    pub queries_blocked: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DnsCacheStats {
    pub entries: usize,
    pub max_entries: usize,
    pub hits: u64,
    pub misses: u64,
    pub evictions: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DnsCacheEntry {
    pub hostname: String,
    pub record_type: String,
    pub ttl_remaining_secs: u32,
    pub cached_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DnsCacheFlushResult {
    pub entries_flushed: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DnsQueryLog {
    pub timestamp: String,
    pub source_ip: String,
    pub hostname: String,
    pub record_type: String,
    pub decision: String,
    pub matched_rule: Option<String>,
    pub upstream_ms: Option<u64>,
    pub cached: bool,
}
```
