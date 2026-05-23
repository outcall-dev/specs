# S007 Success Criteria

| ID | Criterion |
|----|-----------|
| S007-SC-001 | `outcall dns status` confirms the DNS server is listening on the bridge gateway IP, port 53, verified by `ss -ulnp` and `ss -tlnp` showing the bound socket. |
| S007-SC-002 | A DNS query for an allowed hostname from inside a container returns the correct upstream answer with valid IP addresses. |
| S007-SC-003 | A DNS query for a blocked hostname from inside a container returns NXDOMAIN (RCODE 3) with an SOA record in the authority section. |
| S007-SC-004 | A DNS query for a hostname with no matching rule returns NXDOMAIN (default-block policy). |
| S007-SC-005 | Rule evaluation plus NXDOMAIN response construction completes within 10ms, measured from query receipt to response send (excluding upstream resolution time for allowed queries). |
| S007-SC-006 | A container started on an outcall network has `/etc/resolv.conf` containing only `nameserver <bridge_ip>` and `options ndots:0`. Verified by `docker exec <container> cat /etc/resolv.conf`. |
| S007-SC-007 | A second query for a previously-allowed hostname is served from cache without an upstream DNS call, confirmed by the query log showing `cached: true` and no upstream latency. |
| S007-SC-008 | Every DNS query (allowed and blocked) produces a structured log entry containing source IP, hostname, record type, decision, matched rule, cache status, and upstream latency. |
| S007-SC-009 | After `outcalld` shutdown, no UDP or TCP sockets remain bound on the bridge IP port 53. Verified by `ss -ulnp` and `ss -tlnp`. |
| S007-SC-010 | Existing `outcall bridge *`, `outcall network *`, and `outcall rule *` commands continue to work unchanged after the DNS filter is added. |
