# S008 Success Criteria

| ID | Criterion |
|----|-----------|
| S008-SC-001 | `outcall container create --image <img>` creates a container confirmed by `docker inspect` with all required bind mounts, env vars, DNS config, and network attachment. |
| S008-SC-002 | A container create request that includes the host socket path in any bind mount is rejected before reaching Docker. Verified by checking that no Docker API call is issued. |
| S008-SC-003 | The created container is attached to the specified outcall-managed network, confirmed by `docker network inspect`. |
| S008-SC-004 | With helper mounts explicitly enabled, `/usr/local/bin/outcall` exists and is executable, `/run/outcall/agent.sock` exists, and the host socket path (`host.sock`) is NOT accessible from inside the container. With the field omitted, neither helper is mounted. |
| S008-SC-005 | Inside the container, `echo $HTTP_PROXY` and `echo $HTTPS_PROXY` return the proxy address. |
| S008-SC-006 | Inside the container, `/etc/resolv.conf` points at the DNS filter address. |
| S008-SC-007 | `outcall container stop` followed by `outcall container remove` completes the full lifecycle without errors. |
| S008-SC-008 | `outcall container list` accurately reflects all outcall-managed containers and their states. |
| S008-SC-009 | No shell-outs to the `docker` CLI from `outcalld`. |
| S008-SC-010 | On `outcalld` shutdown, all managed containers remain running under the strict base nftables policy with dynamic direct-egress grants removed. On restart, `outcalld` rediscovers them by the `managed-by=outcalld` label. |
| S008-SC-011 | All `outcall container` CLI commands round-trip through the host API and produce correct output. |
| S008-SC-012 | Caller mounts cannot cover the helper shim, agent socket, or resolver path; malformed bind forms are rejected. |
| S008-SC-013 | Inspect, stop, and remove reject every container without the exact managed label and use immutable IDs after inspection. |
| S008-SC-014 | Docker startup availability is based on a bounded `_ping`, and a hung engine produces degraded mode within 3 seconds. |
| S008-SC-015 | A start or identity-registration failure leaves no partial container unless rollback itself fails and is reported. |
| S008-SC-016 | Registry-port, tag, untagged, and digest image references are parsed correctly. |
