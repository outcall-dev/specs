# S007 Edge Cases

| ID | Scenario | Expected Behavior |
|----|----------|-------------------|
| S007-EC-001 | Bridge not up (DNS start) | DNS server does not bind. It waits for the bridge-up event. `outcall dns status` reports `inactive (bridge not up)`. |
| S007-EC-002 | All upstream resolvers unreachable | `outcalld` returns SERVFAIL (RCODE 2) to the container. A warn-level log entry records the failure. The query is not retried automatically. |
| S007-EC-003 | Upstream resolver times out | `outcalld` waits `DNS_UPSTREAM_TIMEOUT_MS` then tries the next upstream. If all upstreams time out, returns SERVFAIL. |
| S007-EC-004 | Malformed DNS query | `outcalld` drops the packet silently for UDP. For TCP, it closes the connection. A debug-level log entry records the malformed query. |
| S007-EC-005 | Rule engine unavailable (e.g., rules directory missing) | `outcalld` returns SERVFAIL for all queries until the rule engine is available. It **MUST NOT** silently allow queries when the rule engine cannot evaluate. |
| S007-EC-006 | Query for outcalld's own address (bridge gateway IP) | Evaluated by the rule engine like any other query. No special-casing. |
| S007-EC-007 | Cache full (max entries reached) | Evict the least-recently-used entry to make room for the new one. No queries are dropped due to a full cache. |
| S007-EC-008 | Port 53 already in use | `outcalld` logs an error and the DNS filter fails to start. The daemon continues running without DNS filtering. `outcall dns status` reports the bind failure. |
| S007-EC-009 | Hostname exceeds 253 characters (DNS max) | `outcalld` returns FORMERR (RCODE 1). The query is not forwarded to the rule engine. |
| S007-EC-010 | Rapid duplicate queries for the same hostname | The first query is forwarded; concurrent duplicate queries for the same `(hostname, record_type)` **SHOULD** coalesce and share the upstream response. |
| S007-EC-011 | EDNS0 OPT record in query | `outcalld` **MUST** handle EDNS0 queries. The OPT record is preserved when forwarding to upstream. The advertised UDP buffer size from the client is respected when determining whether to truncate. |
| S007-EC-012 | Daemon shutdown while queries are in-flight | In-flight queries get up to 5 seconds to complete. After the grace period, remaining queries are dropped and sockets are closed. |
| S007-EC-013 | Upstream returns SERVFAIL | `outcalld` tries the next upstream if available. If all upstreams return SERVFAIL, the SERVFAIL is returned to the container. The response is not cached. |
| S007-EC-014 | PTR (reverse DNS) queries | Evaluated by the rule engine with `dns.query` set to the reverse lookup name (e.g., `1.0.200.10.in-addr.arpa`) and `dns.record_type` set to `"PTR"`. If allowed, forwarded to upstream. |
| S007-EC-015 | DNS amplification (query from outside the bridge) | The DNS server binds only to the bridge gateway IP. Queries from addresses outside the outcall subnet **MUST** be dropped. |
