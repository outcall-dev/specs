# S008 Functional Requirements

### Container creation

S008-FR-001 [P1] `outcalld` **MUST** communicate with the Docker Engine via the `bollard` crate. It **MUST NOT** shell out to the `docker` CLI.

S008-FR-002 [P1] `outcalld` **MUST** create agent containers with all of the following parameters applied at creation time:
S008-FR-002.a Network: attached to the specified outcall-managed network (default: `outcall-default`)
S008-FR-002.b Optional helper bind mount: `agent.sock` mounted read-only at `/run/outcall/agent.sock`
S008-FR-002.c Optional helper bind mount: `outcall-agent` shim mounted read-only at `/usr/local/bin/outcall`
S008-FR-002.d Environment: `HTTP_PROXY` and `HTTPS_PROXY` set to the HTTP proxy address (S006)
S008-FR-002.e Environment: `NO_PROXY` set to `localhost,127.0.0.1`
S008-FR-002.f DNS: container DNS resolver set to the DNS filter address (S007)
S008-FR-002.g Labels: `managed-by=outcalld` and `outcall.network=<network-name>`

S008-FR-003 [P1] The network specified in the create request **MUST** already exist and its inspected Docker driver and bridge option **MUST** match the daemon's managed bridge. A matching name alone is insufficient. Otherwise the create endpoint **MUST** return an error.

### Bind mount security

S008-FR-004 [P1] When `include_outcall_helper_mounts` is explicitly enabled, `outcalld` **MUST** bind-mount `agent.sock` into the container at `/run/outcall/agent.sock` as read-only. Omitted values **MUST** default to disabled because paths in a containerized daemon namespace are not necessarily valid Docker-host bind sources.

S008-FR-005 [P1] When `include_outcall_helper_mounts` is enabled, `outcalld` **MUST** bind-mount the `outcall-agent` shim binary at `/usr/local/bin/outcall` as read-only.

S008-FR-006 [P1] `outcalld` **MUST** set `HTTP_PROXY` and `HTTPS_PROXY` environment variables on the container, pointing at the HTTP proxy address configured for the attached network.

S008-FR-007 [P1] `outcalld` **MUST** configure the container's DNS resolver to point at the DNS filter address (S007). This is set via the `Dns` field in Docker's `HostConfig`.

### Host socket protection

S008-FR-008 [P1] `outcalld` **MUST** maintain a deny list of paths that **MUST NOT** be bind-mounted into containers. It **MUST** include the configured host API socket plus Docker and containerd control sockets. Static control paths **MUST** be defined in `outcall-api`; the configured host socket **MUST** be added at runtime.

S008-FR-009 [P1] Before issuing any container create call to the Docker API, `outcalld` **MUST** validate every bind source against both lexical and canonical deny-path identities. A source equal to a protected path, a symlink to one, or an ancestor mount that would expose one **MUST** be rejected before Docker is called. The error **MUST** identify the source and protected path.

S008-FR-033 [P1] Caller-provided bind specifications **MUST** have exactly `source:destination[:options]` form and an absolute container destination. A destination equal to or covering `/run/outcall/agent.sock`, `/usr/local/bin/outcall`, or `/etc/resolv.conf` **MUST** be rejected before Docker is called so caller mounts cannot shadow daemon-owned controls.

S008-FR-039 [P1] Before creating a container with helper mounts enabled, `outcalld` **MUST** verify that the agent socket source is a real Unix socket and that the shim source is a real executable file. Missing, wrong-type, non-executable, and symlinked helper sources **MUST** be rejected before Docker is called.

### Container naming

S008-FR-010 [P1] A caller-provided container name **MUST** be used exactly. If omitted, `outcalld` **MUST** generate `outcall-` followed by 8 random lowercase hex characters. Recipe callers implement project-specific `<folder>-N` names above this API.

### Container lifecycle

S008-FR-011 [P1] After creation, `outcalld` **MUST** ask Docker to start the container and register its immutable managed identity before returning success. A one-shot container **MAY** exit immediately after Docker accepts the start; this is not a create failure.

S008-FR-012 [P1] The stop endpoint **MUST** send a SIGTERM to the container's main process and wait up to the configured timeout (default: 10 seconds) before sending SIGKILL.

S008-FR-013 [P1] The remove endpoint **MUST** remove a stopped container and its anonymous volumes. If the container is still running and `force` is not set, the remove endpoint **MUST** return an error.

S008-FR-014 [P1] The list endpoint **MUST** return all containers labeled `managed-by=outcalld`, independent of their operator-visible name. For each container, it **MUST** include the container ID, name, image, state, network, and creation time.

S008-FR-015 [P2] The inspect endpoint **MUST** return detailed information about a single container: ID, name, image, state, network, IP address, bind mounts, environment variable names, and creation time. Every environment value **MUST** be replaced by `<redacted>` before it crosses the daemon API boundary.

S008-FR-034 [P1] Stop, remove, and inspect **MUST** first inspect the requested container and require `managed-by=outcalld`. Stop and remove **MUST** act on the inspected immutable Docker ID, not the mutable caller-supplied name. An already-stopped managed container returns `stopped: false`; an absent container returns `removed: false` from remove. Unmanaged containers **MUST NOT** be inspected, stopped, or removed through Outcall.

S008-FR-035 [P1] If start or managed-identity registration fails after Docker creates a container, `outcalld` **MUST** force-remove that partial container and its anonymous volumes. If rollback also fails, the returned error **MUST** include both failures.

### Resource limits

S008-FR-016 [P2] `outcalld` **SHOULD** apply resource limits at container creation:
S008-FR-016.a Memory limit (default: 512 MiB)
S008-FR-016.b CPU shares (default: 1024, normal priority)
S008-FR-016.c PID limit (default: 256)
S008-FR-016.d The operator **MAY** override defaults via the create request.
S008-FR-016.e Explicit memory limits below 6 MiB and CPU shares below 2 **MUST** be rejected before Docker creation.

### Image management

S008-FR-017 [P2] `outcalld` **SHOULD** provide an image pull endpoint that pulls a specified image from a registry before container creation. If the image is not available locally at create time, `outcalld` **MUST** return an error rather than blocking on an implicit pull.

S008-FR-037 [P2] Image pull parsing **MUST** distinguish a registry port from an image tag, preserve digest references, default an untagged reference to `latest`, and reject empty, whitespace-containing, or empty-tag references before contacting Docker.

### Daemon integration

S008-FR-018 [P1] The Docker Manager **MUST** run as a Tokio task within the existing `outcalld` process. There **MUST NOT** be a separate process.

S008-FR-019 [P1] The container endpoints **MUST** be served on the host unix socket only. They **MUST NOT** be exposed on the agent-facing socket.

S008-FR-020 [P1] On daemon shutdown, `outcalld` **MUST NOT** stop or remove outcall-managed containers. Containers intentionally outlive the daemon so that running workloads are not disrupted (consistent with S002-EC-010). Existing containers are rediscovered by the `managed-by=outcalld` label.

S008-FR-036 [P1] Manager initialization **MUST** perform a bounded Docker `_ping` request (maximum 3 seconds). Client construction alone is not proof of availability. A failed or timed-out ping **MUST** produce truthful degraded mode while the policy daemon continues running.

### CLI integration

S008-FR-021 [P1] The `outcall` CLI **MUST** add a `container` subcommand with sub-subcommands: `create`, `list`, `inspect`, `stop`, `remove`, `pull`.

S008-FR-022 [P1] The CLI **MUST** communicate with `outcalld` using the same raw HTTP/1.0-over-unix-socket mechanism used by the existing `bridge` and `network` commands.

S008-FR-023 [P1] On error responses from the API, the CLI **MUST** print the error message to stderr and exit with code 1.

### Defaults and configuration

S008-FR-024 [P1] The container prefix, shim container path, agent socket container path, default stop timeout, default memory limit, and default CPU shares **MUST** be defined as constants in `outcall-api`.

### Hardening

S008-FR-025 [P2] `outcalld` **SHOULD** create containers with a read-only root filesystem. A writable tmpfs **SHOULD** be mounted at `/tmp`.

S008-FR-026 [P2] `outcalld` **MUST NOT** create containers in privileged mode.

S008-FR-027 [P2] `outcalld` **SHOULD** drop all Linux capabilities except those required by the agent workload. The default set **SHOULD** be empty (`[]`).

S008-FR-027.a [P1] Managed containers **MUST** set `no-new-privileges` and **MUST NOT** accept caller-provided capability additions.

S008-FR-027.b [P1] Managed containers **MUST** run with a numeric non-root
`UID:GID`. Caller-provided identities **MUST** contain exactly two nonzero
numeric components. Omitted identities **MUST** use a daemon-owned non-root
default.

S008-FR-038 [P1] Docker `HostConfig.NetworkMode` **MUST** name the same inspected managed network used by `NetworkingConfig`. Managed containers **MUST** enable Docker init, set DNS `ndots:0`, and receive no daemon-supported path for adding a second network.

### Stop behavior

S008-FR-028 [P1] The default stop timeout **MUST** be 10 seconds. The operator **MAY** override this per-request.

### Container metadata

S008-FR-029 [P2] `outcalld` **SHOULD** apply Docker labels to each container: `managed-by=outcalld`, `outcall.network=<network>`, `outcall.created-at=<ISO8601>`.

### Container event stream

S008-FR-031 [P1] `outcalld` **MUST** subscribe to Docker container events (via the `bollard` events API) for all outcall-managed containers. The event stream **MUST** detect container death from any cause: explicit stop/remove, OOM kill, crash, or external `docker rm -f`. This stream is consumed by S009 (Dynamic Rules) for nftables rule cleanup.

S008-FR-032 [P1] A network is considered outcall-managed only when its name starts with `outcall-`, its Docker driver is `bridge`, and `com.docker.network.bridge.name` equals the bridge configured for this daemon. All three properties **MUST** be inspected.

### Prerequisites

S008-FR-030 [P1] `outcalld` **MUST** inspect and validate the target network under S008-FR-032 before creating a container. Missing, default-bridge, host, name-only forged, or wrong-bridge networks **MUST** be rejected.
