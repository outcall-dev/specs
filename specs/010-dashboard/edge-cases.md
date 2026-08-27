# S010 Edge Cases

| ID | Scenario | Expected Behavior |
|----|----------|-------------------|
| S010-EC-001 | Dashboard accessed on macOS with the Docker-hosted daemon runtime | Dashboard loads through the loopback browser bridge and reports the Linux runtime bridge state without exposing the daemon API to the LAN. |
| S010-EC-002 | No containers running | Container list is empty. Dashboard shows "0 containers" in overview. |
| S010-EC-003 | DNS rebinding or cross-origin request | Reject with 403 before connecting to the host socket. |
| S010-EC-004 | Missing, invalid, or duplicate bridge token | Reject protected API request with 401 or malformed duplicate with 400. |
| S010-EC-005 | Ambiguous framing or oversized request | Reject the connection with 400, 413, or 431 without forwarding partial input. |
| S010-EC-006 | More than 64 concurrent connections | Reject excess connections with 503 and recover capacity when active handlers exit. |
| S010-EC-007 | Dashboard loads before the launcher adds its fragment token | Remain tokenless without API traffic, then activate once on `hashchange`, clear the fragment, and avoid duplicate polling timers. |
