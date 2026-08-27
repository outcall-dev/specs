# S002 Functional Requirements

### Network creation

S002-FR-001 [P1] `outcalld` **MUST** communicate with the Docker Engine via its API. It **MUST NOT** shell out to the `docker` CLI.

S002-FR-002 [P1] `outcalld` **MUST** create networks with these parameters:
S002-FR-002.a Driver: `bridge`
S002-FR-002.b Bridge name option: `com.docker.network.bridge.name` set to the configured bridge name
S002-FR-002.c Subnet and gateway from auto-allocation or explicit override

S002-FR-003 [P1] The create operation **MUST** be idempotent. If a network with the given name already exists and has the required driver and bridge identity, the endpoint **MUST** return success with `created: false`. A same-name network with different identity **MUST** be rejected.

S002-FR-004 [P1] `outcalld` **MUST** verify that the bridge is up before creating any network. If the bridge is not initialized, the endpoint **MUST** return an error.

S002-FR-005 [P1] After creation, `outcalld` **MUST** re-inspect the network and verify its immutable ID, bridge driver, configured bridge interface, subnet, and gateway before returning success.

### Default network

S002-FR-006 [P1] The default network name **MUST** be `outcall-default`. With the default allocation block it uses subnet `10.200.0.0/24` and gateway `10.200.0.1`; with a custom allocation block it uses that block's first `/24` and first usable address.

S002-FR-007 [P1] When `outcall network create` is called without `--name`, it **MUST** create the default network.

S002-FR-008 [P1] The default network **MAY** be destroyed like any other network. Running `outcall network create` with no `--name` afterward **MUST** recreate it with its default subnet.

### Named networks

S002-FR-009 [P1] The create endpoint **MUST** accept a `name` parameter. The `outcall-` prefix is automatically prepended — `--name staging` creates `outcall-staging`.

S002-FR-010 [P1] All networks (default and named) **MUST** share the same bridge interface so they are governed by the same nftables policy.

S002-FR-011 [P2] The user-provided name portion **MUST** be validated: alphanumeric, hyphens, and underscores only, 1-64 characters. The `outcall-` prefix is always prepended by the system.

### Subnet auto-allocation

S002-FR-012 [P1] When no explicit subnet is provided, `outcalld` **MUST** auto-allocate the next available `/24` from the `10.200.0.0/16` block by scanning `10.200.0.0/24` through `10.200.255.0/24` and picking the first unused slot.

S002-FR-013 [P1] Before allocating, `outcalld` **MUST** check both its own managed networks AND all Docker networks (via the Docker API) for subnet collisions. A subnet is considered in-use if any Docker network's IPAM config overlaps with it.

S002-FR-014 [P2] If all 256 `/24` subnets in the default block are in use, the create endpoint **MUST** return an error: `"no available subnets in 10.200.0.0/16"`.

S002-FR-015 [P1] An explicit `--subnet` override **MUST** be a canonical IPv4 CIDR wholly inside one RFC 1918 range, provide usable gateway and container addresses, and be checked for overlap with every existing Docker IPv4 subnet before creation. An explicit gateway **MUST** be a usable address inside that subnet.

### Network status and listing

S002-FR-016 [P1] The status endpoint **MUST** return whether the network exists, and if it does: the network ID, name, subnet, gateway, and a list of connected containers with their names and IPv4 addresses.

S002-FR-017 [P1] `outcalld` **MUST** query Docker on every status request. It **MUST NOT** cache network state.

S002-FR-018 [P1] The list endpoint **MUST** return all outcall-managed networks. A network is considered managed only when its name starts with `outcall-`, its driver is `bridge`, and `com.docker.network.bridge.name` exactly matches the configured Outcall bridge. Prefix-only lookalikes **MUST** be ignored and logged.

### Network destruction

S002-FR-019 [P1] The destroy endpoint **MUST** refuse to remove a network if any containers are connected. The error response **MUST** include the names of connected containers.

S002-FR-020 [P2] If the target network does not exist, the destroy endpoint **MUST** return success (idempotent teardown).

S002-FR-021 [P1] `outcalld` **MUST NOT** forcibly disconnect containers. The operator is responsible for stopping or disconnecting containers first.

### Daemon integration

S002-FR-022 [P1] Docker management **MUST** run within the existing `outcalld` process. There **MUST NOT** be a separate process.

S002-FR-023 [P2] `outcalld` **MUST** initialize a Docker client at startup. Connection failure at startup **SHOULD** be logged as a warning but **MUST NOT** prevent the daemon from starting.

S002-FR-032 [P1] On startup, `outcalld` **MUST** rediscover existing outcall-managed networks by querying Docker for networks whose name starts with the `outcall-` prefix and validating each network's managed identity. This ensures that networks created in a previous daemon session (which outlive the daemon per S002-EC-010) are visible without accepting prefix-only lookalikes.

S002-FR-024 [P1] The network endpoints **MUST** be served on the host unix socket only. They **MUST NOT** be exposed on any agent-facing socket.

### CLI integration

S002-FR-025 [P1] The `outcall` CLI **MUST** add a `network` subcommand with four sub-subcommands: `create`, `status`, `list`, `destroy`.

S002-FR-026 [P1] The CLI **MUST** communicate with `outcalld` using the same raw HTTP/1.0-over-unix-socket mechanism used by the existing `bridge` commands.

S002-FR-027 [P1] On error responses from the API, the CLI **MUST** print the error message to stderr and exit with code 1.

### Defaults and configuration

S002-FR-028 [P1] The network prefix, subnet block, default network name, default subnet, and default gateway **MUST** be defined as constants in `outcall-api`.

S002-FR-029 [P2] `outcalld` **SHOULD** accept a `--subnet-block` flag (e.g. `--subnet-block 10.201.0.0/16`) to override the default `10.200.0.0/16` allocation block. When set, auto-allocation and the default network subnet **MUST** use the provided block instead.

S002-FR-030 [P2] The `--subnet-block` value **MUST** be a canonical IPv4 CIDR, no smaller than `/24`, and wholly contained in one RFC 1918 range. `outcalld` **MUST** reject host bits, non-private ranges, and ranges that cross a private-space boundary at startup.

S002-FR-031 [P2] The configured subnet block **MUST** be queryable via `GET /api/v1/network/config` so the CLI and other tools can discover the active allocation range.

S002-FR-033 [P1] Status and destroy operations **MUST** verify the target network's managed identity before returning details or removing it. A forged `outcall-*` network **MUST NOT** be treated as an Outcall security boundary or deleted by Outcall.
