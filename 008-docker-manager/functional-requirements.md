# S008 Functional Requirements

### Container creation

S008-FR-001 [P1] `outcalld` **MUST** communicate with the Docker Engine via the `bollard` crate. It **MUST NOT** shell out to the `docker` CLI.

S008-FR-002 [P1] `outcalld` **MUST** create agent containers with all of the following parameters applied at creation time:
S008-FR-002.a Network: attached to the specified outcall-managed network (default: `outcall-default`)
S008-FR-002.b Bind mount: `agent.sock` mounted read-only at `/run/outcall/agent.sock`
S008-FR-002.c Bind mount: `outcall-agent` shim mounted read-only at `/usr/local/bin/outcall`
S008-FR-002.d Environment: `HTTP_PROXY` and `HTTPS_PROXY` set to the HTTP proxy address (S006)
S008-FR-002.e Environment: `NO_PROXY` set to `localhost,127.0.0.1`
S008-FR-002.f DNS: container DNS resolver set to the DNS filter address (S007)
S008-FR-002.g Labels: `managed-by=outcalld` and `outcall.network=<network-name>`

S008-FR-003 [P1] The network specified in the create request **MUST** already exist as an outcall-managed network. If it does not, the create endpoint **MUST** return an error.

### Bind mount security

S008-FR-004 [P1] `outcalld` **MUST** bind-mount the `agent.sock` socket into the container at `/run/outcall/agent.sock` as read-only.

S008-FR-005 [P1] `outcalld` **MUST** bind-mount the `outcall-agent` shim binary into the container at `/usr/local/bin/outcall` as read-only.

S008-FR-006 [P1] `outcalld` **MUST** set `HTTP_PROXY` and `HTTPS_PROXY` environment variables on the container, pointing at the HTTP proxy address configured for the attached network.

S008-FR-007 [P1] `outcalld` **MUST** configure the container's DNS resolver to point at the DNS filter address (S007). This is set via the `Dns` field in Docker's `HostConfig`.

### Host socket protection

S008-FR-008 [P1] `outcalld` **MUST** maintain a deny list of paths that **MUST NOT** be bind-mounted into containers. This deny list **MUST** include the host socket path (default: `/run/outcall/host.sock`, or the value of `--socket` if overridden). The deny list constant **MUST** be defined in `outcall-api`.

S008-FR-009 [P1] Before issuing any container create call to the Docker API, `outcalld` **MUST** validate every bind mount source path against the deny list. If any bind mount source resolves to a denied path (after symlink resolution), the create call **MUST** be rejected before reaching Docker. The error message **MUST** identify the denied path.

### Container naming

S008-FR-010 [P1] All agent containers **MUST** be named with the `outcall-agent-` prefix followed by 8 random lowercase hex characters (e.g. `outcall-agent-a3f7b201`). If a `name` is provided in the create request, it **MUST** be used as a suffix instead of random hex, with the `outcall-agent-` prefix still prepended.

### Container lifecycle

S008-FR-011 [P1] After creation, `outcalld` **MUST** start the container. The create endpoint **MUST** return only after the container has transitioned to the `running` state or failed to start.

S008-FR-012 [P1] The stop endpoint **MUST** send a SIGTERM to the container's main process and wait up to the configured timeout (default: 10 seconds) before sending SIGKILL.

S008-FR-013 [P1] The remove endpoint **MUST** remove a stopped container and its anonymous volumes. If the container is still running and `force` is not set, the remove endpoint **MUST** return an error.

S008-FR-014 [P1] The list endpoint **MUST** return all containers whose name starts with the `outcall-agent-` prefix. For each container, it **MUST** include the container ID, name, image, state, network, and creation time.

S008-FR-015 [P2] The inspect endpoint **MUST** return detailed information about a single container: ID, name, image, state, network, IP address, bind mounts, environment variables, and creation time.

### Resource limits

S008-FR-016 [P2] `outcalld` **SHOULD** apply resource limits at container creation:
S008-FR-016.a Memory limit (default: 512 MiB)
S008-FR-016.b CPU shares (default: 1024, normal priority)
S008-FR-016.c PID limit (default: 256)
S008-FR-016.d The operator **MAY** override defaults via the create request.

### Image management

S008-FR-017 [P2] `outcalld` **SHOULD** provide an image pull endpoint that pulls a specified image from a registry before container creation. If the image is not available locally at create time, `outcalld` **MUST** return an error rather than blocking on an implicit pull.

### Daemon integration

S008-FR-018 [P1] The Docker Manager **MUST** run as a Tokio task within the existing `outcalld` process. There **MUST NOT** be a separate process.

S008-FR-019 [P1] The container endpoints **MUST** be served on the host unix socket only. They **MUST NOT** be exposed on the agent-facing socket.

S008-FR-020 [P1] On daemon shutdown, `outcalld` **MUST NOT** stop or remove outcall-managed containers. Containers intentionally outlive the daemon so that running workloads are not disrupted (consistent with S002-EC-010). When the daemon restarts, it rediscovers existing containers by scanning for the `outcall-agent-` name prefix.

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

### Stop behavior

S008-FR-028 [P1] The default stop timeout **MUST** be 10 seconds. The operator **MAY** override this per-request.

### Container metadata

S008-FR-029 [P2] `outcalld` **SHOULD** apply Docker labels to each container: `managed-by=outcalld`, `outcall.network=<network>`, `outcall.created-at=<ISO8601>`.

### Container event stream

S008-FR-031 [P1] `outcalld` **MUST** subscribe to Docker container events (via the `bollard` events API) for all outcall-managed containers. The event stream **MUST** detect container death from any cause: explicit stop/remove, OOM kill, crash, or external `docker rm -f`. This stream is consumed by S009 (Dynamic Rules) for nftables rule cleanup.

S008-FR-032 [P1] A network is considered "outcall-managed" if its Docker name starts with the `outcall-` prefix (as defined by S002-FR-009). All validation against this criterion **MUST** use prefix matching on the Docker network name.

### Prerequisites

S008-FR-030 [P1] `outcalld` **MUST** verify that the target network exists and is an outcall-managed network (S008-FR-032) before creating a container. If the network does not exist or is not outcall-managed, the create endpoint **MUST** return an error.
