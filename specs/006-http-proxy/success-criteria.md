# S006 Success Criteria

| ID | Criterion |
|----|-----------|
| S006-SC-001 | An HTTP GET from an agent container to an allowed host succeeds, returning the upstream response through the proxy. |
| S006-SC-002 | An HTTPS request from an agent container to an allowed host completes a TLS handshake end-to-end through the proxy tunnel. |
| S006-SC-003 | An HTTP or HTTPS request to a blocked host returns HTTP 403 with the block reason. No bytes reach the upstream. |
| S006-SC-004 | The SNI hostname extracted from a TLS ClientHello matches the `network.hostname` value evaluated by the rule engine. |
| S006-SC-005 | The proxy starts when `outcalld` starts and stops when `outcalld` stops. No orphan listener remains. |
| S006-SC-006 | `tcpdump` or equivalent confirms no TLS decryption -- the proxy tunnels raw encrypted bytes after SNI peek. |
| S006-SC-007 | Every policy-blocked request produces a structured warning/error with source IP, hostname, method where applicable, and reason, without secret-bearing request data. |
| S006-SC-008 | 10 concurrent agent containers can make simultaneous HTTP/HTTPS requests without interference or deadlock. |
| S006-SC-009 | An idle tunnel is closed after the configured idle timeout. A connect attempt that exceeds the connect timeout returns 504. |
| S006-SC-010 | Agent containers launched on an outcall network have `HTTP_PROXY`, `HTTPS_PROXY`, `http_proxy`, `https_proxy`, and `NO_PROXY` environment variables set correctly. |
