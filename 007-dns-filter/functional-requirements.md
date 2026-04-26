# S007 Functional Requirements

### DNS server lifecycle

S007-FR-001 [P1] `outcalld` **MUST** start a DNS server that binds to the bridge gateway IP address (e.g., `10.200.0.1`) on port 53. The listen address **MUST** be derived from the active bridge configuration (S001/S002), not hardcoded.

S007-FR-002 [P1] The DNS server **MUST** listen on both UDP and TCP on the same address and port. UDP is the primary transport; TCP is required for responses that exceed 512 bytes (or the EDNS0 buffer size).

S007-FR-003 [P1] The DNS server **MUST** run as a Tokio task inside `outcalld`. There **MUST NOT** be a separate process.

S007-FR-004 [P1] The DNS server **MUST NOT** start until the bridge is up. If the bridge is not initialized when `outcalld` starts, the DNS task **MUST** wait for the bridge-up event before binding.

S007-FR-005 [P1] On daemon shutdown, the DNS server **MUST** stop accepting new queries and **MUST** allow in-flight queries up to 5 seconds to complete before forcibly dropping them. All sockets **MUST** be closed.

### Container resolv.conf injection

S007-FR-006 [P1] When `outcalld` starts a container on an outcall network, it **MUST** configure the container's `/etc/resolv.conf` to use the bridge gateway IP as the sole nameserver. The generated resolv.conf **MUST** contain:
S007-FR-006.a `nameserver <bridge_gateway_ip>` as the only nameserver line
S007-FR-006.b `options ndots:0` to prevent search domain appending for FQDNs
S007-FR-006.c No `search` directive

### Query interception and parsing

S007-FR-007 [P1] `outcalld` **MUST** parse incoming DNS queries using the `hickory-dns` crate (formerly trust-dns). It **MUST** extract the queried hostname and record type (e.g., `A`, `AAAA`, `CNAME`, `MX`, `TXT`, `SRV`, `PTR`) from each query.

S007-FR-008 [P1] For each incoming query, `outcalld` **MUST** construct an `EvaluationContext` with a populated `DnsContext` and submit it to the rule engine (S003) for evaluation. The `DnsContext` **MUST** contain:
S007-FR-008.a `query` -- the queried hostname, normalized to lowercase with no trailing dot
S007-FR-008.b `record_type` -- the query type as an uppercase string (e.g., `"A"`, `"AAAA"`, `"MX"`)

S007-FR-009 [P1] The CEL context variables exposed for DNS policy evaluation **MUST** be:
S007-FR-009.a `dns.query` -- the hostname being resolved (string)
S007-FR-009.b `dns.record_type` -- the record type (string)

### NXDOMAIN responses

S007-FR-010 [P1] When the rule engine returns a BLOCK decision, `outcalld` **MUST** return a DNS response with:
S007-FR-010.a Response code: NXDOMAIN (RCODE 3)
S007-FR-010.b The question section echoed back
S007-FR-010.c An SOA record in the authority section with a minimal TTL (60 seconds) to discourage immediate retries
S007-FR-010.d No answer section records

### Upstream forwarding

S007-FR-011 [P1] When the rule engine returns an ALLOW decision, `outcalld` **MUST** forward the original DNS query to the configured upstream resolver and return the upstream response to the agent unmodified.

S007-FR-012 [P1] `outcalld` **MUST** accept a `--dns-upstream` flag to configure upstream DNS resolvers. The flag accepts comma-separated `IP:port` values (e.g., `--dns-upstream 8.8.8.8:53,8.8.4.4:53`). If only an IP is provided, port 53 is assumed.

S007-FR-013 [P1] If `--dns-upstream` is not provided, `outcalld` **MUST** parse the host system's `/etc/resolv.conf` at startup and use the nameservers listed there as upstreams.

S007-FR-014 [P2] `outcalld` **SHOULD** support multiple upstream resolvers. When multiple upstreams are configured, they **MUST** be tried in the order specified.

S007-FR-015 [P2] If an upstream resolver does not respond within the configured timeout (`DNS_UPSTREAM_TIMEOUT_MS`), `outcalld` **MUST** try the next upstream in the list. If all upstreams fail, `outcalld` **MUST** return SERVFAIL to the agent.

### Response caching

S007-FR-016 [P2] `outcalld` **SHOULD** cache successful upstream responses for allowed queries. The cache key **MUST** be `(lowercase_hostname, record_type)`.

S007-FR-017 [P2] Cached entries **MUST** respect the minimum TTL from the upstream response's answer records. The effective cache TTL **MUST** be `min(upstream_min_ttl, DNS_CACHE_MAX_TTL_SECS)`. When serving a cached response, the TTL values in the answer **MUST** be decremented to reflect elapsed time.

S007-FR-018 [P2] When the rule engine reloads rules (S003-FR-021), the DNS cache **MUST** be flushed entirely. This ensures that previously-allowed hostnames that are now blocked are not served from cache.

S007-FR-019 [P2] The cache **MUST** have a maximum entry count (`DNS_CACHE_MAX_ENTRIES`). When full, the least-recently-used entry **MUST** be evicted.

### DNS over TCP

S007-FR-020 [P1] The DNS server **MUST** handle TCP connections for queries and responses. When an upstream response is truncated (TC bit set) over UDP, `outcalld` **MUST** retry the query to the upstream over TCP. TCP connections **MUST** be closed after the configured timeout (`DNS_TCP_TIMEOUT_MS`) of inactivity.

### DNSSEC

S007-FR-021 [P2] `outcalld` **MUST** pass through DNSSEC-related records (RRSIG, DNSKEY, DS, NSEC, NSEC3) from upstream responses without modification. `outcalld` **MUST NOT** perform DNSSEC validation itself. If the agent's DNS client performs validation, the records **MUST** arrive intact.

### Logging

S007-FR-022 [P1] `outcalld` **MUST** log every DNS query with:
S007-FR-022.a Source IP address of the querying container
S007-FR-022.b Queried hostname
S007-FR-022.c Record type
S007-FR-022.d Decision (allow/block)
S007-FR-022.e Matched rule ID (if any) or "default-block"
S007-FR-022.f Whether the response was served from cache
S007-FR-022.g Upstream resolution time in milliseconds (if forwarded)

S007-FR-023 [P1] Rule evaluation plus response construction for a DNS query **MUST** complete within 10ms (excluding upstream resolution time). The upstream resolution timeout is governed separately by `DNS_UPSTREAM_TIMEOUT_MS`.

### Implementation

S007-FR-024 [P1] The DNS server **MUST** be implemented using the `hickory-dns` crate (`hickory-server` for the server, `hickory-resolver` for upstream resolution). `outcalld` **MUST NOT** implement DNS wire protocol parsing manually.

S007-FR-025 [P1] All DNS filter operations **MUST** use structured logging (`tracing` crate) at appropriate levels: `info` for startup/shutdown, `debug` for individual query decisions, `warn` for upstream failures, `error` for bind failures.

S007-FR-026 [P1] DNS filter errors **MUST** use typed error variants in the `OutcallError` enum. At minimum: `DnsBindError`, `DnsUpstreamError`, `DnsQueryError`.

### Host API and CLI

S007-FR-027 [P1] The DNS filter status **MUST** be queryable via the host API. The status endpoint **MUST** return whether the DNS server is running, its listen address, configured upstreams, cache entry count, and query counters.

S007-FR-028 [P1] The `outcall` CLI **MUST** add a `dns` subcommand with sub-subcommands: `status`, `test`, `cache`, `flush`.

S007-FR-029 [P2] The DNS server listen port **SHOULD** be configurable via `--dns-port`. The default **MUST** be 53.

S007-FR-030 [P2] `outcalld` **SHOULD** expose cache statistics (entries, hits, misses, evictions) via the host API.

S007-FR-031 [P3] `outcalld` **MAY** expose per-hostname query count metrics via the host API for observability.

### Fail-closed

S007-FR-032 [P1] If the rule engine returns an error or is unavailable, the DNS server **MUST** return SERVFAIL (fail-closed). It **MUST NOT** silently forward the query or return an allow-equivalent response. This behavior **MUST NOT** be configurable.

### DNS safety

S007-FR-033 [P2] Queries for `.local` domains (mDNS) **MUST** be returned as NXDOMAIN without forwarding to upstream resolvers.

S007-FR-034 [P2] When an ALLOW verdict is returned and the upstream resolves a public hostname to an RFC 1918 address (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) or loopback (127.0.0.0/8), `outcalld` **MUST** log a warning (potential DNS rebinding). `outcalld` **MAY** be configured to treat such responses as BLOCK via a `--dns-rebind-protection` flag (default: warn-only).

### Rule-configurable egress mode

S007-FR-035 [P1] DNS allow rules **MAY** include an optional `egress` block with `mode: proxy|direct_ip`.

S007-FR-036 [P1] When `egress.mode` is `proxy`, `outcalld` **MUST NOT** open direct nftables L3/L4 allow rules from DNS results. This mode is the recommended default for shared IP/CDN safety.

S007-FR-037 [P1] When `egress.mode` is `direct_ip`, `outcalld` **MUST** derive IPv4 destinations from the allowed DNS response and insert per-container dynamic nftables allow rules for TCP destination ports listed in `egress.ports`.

S007-FR-038 [P2] If `egress.mode` is `direct_ip` and `egress.ports` is omitted or empty, `outcalld` **MUST** default to `[80, 443]`.
