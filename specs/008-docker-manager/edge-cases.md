# S008 Edge Cases

| ID | Scenario | Expected Behavior |
|----|----------|-------------------|
| S008-EC-001 | Host socket path in bind mounts | Reject before calling Docker API. Error identifies the denied path. This is the critical security invariant. |
| S008-EC-002 | Target network does not exist | Return error. Do not create the container. |
| S008-EC-003 | Docker daemon unreachable | Return error with descriptive message. |
| S008-EC-004 | Container does not exist (stop/remove) | Return error: `container "<name>" does not exist`. |
| S008-EC-005 | Image not found locally (create) | Return error: `image "<image>" not found locally — pull it first`. Do not trigger implicit pull. |
| S008-EC-006 | Image pull fails (network error, auth) | Return error with the upstream Docker message. |
| S008-EC-007 | Stop called on already-stopped container | Return success with `stopped: false`. Idempotent. |
| S008-EC-008 | Remove called on already-removed container | Return success with `removed: false`. Idempotent. |
| S008-EC-009 | Multiple rapid create calls | Each call generates a unique name. No collision due to random hex suffix. |
| S008-EC-010 | Daemon shutdown with running containers | Containers are NOT stopped. Dynamic direct-egress grants are removed, and the strict base nftables policy remains active while proxy, DNS, and control sockets are unavailable. On restart, `outcalld` rediscovers containers by the `managed-by=outcalld` label and restores control-plane services. |
| S008-EC-011 | Docker available at startup but disappears later | Individual endpoint calls return Docker connection errors. The daemon continues running. |
| S008-EC-012 | Symlink traversal in bind mount source | `outcalld` **MUST** resolve symlinks before checking the deny list. A symlink to the host socket **MUST** be caught. |
| S008-EC-013 | Duplicate container name (custom suffix collides) | Docker rejects the create. `outcalld` returns the Docker error to the caller. |
| S008-EC-014 | Resource limit exceeds host capacity | Docker may accept the create but OOM-kill the container. `outcalld` does not pre-validate against host resources. |
| S008-EC-015 | Agent socket path does not exist on host | Return error: `agent socket not found at "<path>"`. Do not create the container. |
| S008-EC-016 | Shim binary path does not exist on host | Return error: `shim binary not found at "<path>"`. Do not create the container. |
| S008-EC-017 | Helper source is a symlink, wrong type, or non-executable shim | Reject before Docker create. Helper source identity is never followed through a symlink. |
| S008-EC-018 | Caller mount shadows shim, agent socket, resolver, or a parent directory | Reject before Docker create, including named-volume sources and mounts targeting `/`. |
| S008-EC-019 | Inspect, stop, or remove names an unmanaged container | Reject without exposing details or changing the container. |
| S008-EC-020 | Docker client construction succeeds but `_ping` hangs | Enter degraded mode after the 3-second bound. Do not report Docker initialized. |
| S008-EC-021 | Registry address contains a port but no image tag | Preserve the registry port and use `latest`; do not parse the port as a tag. |
