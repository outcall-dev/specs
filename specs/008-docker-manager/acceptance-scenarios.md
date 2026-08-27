# S008 Acceptance Scenarios

### S008-AS-001 Create: agent container with all constraints [P1]

**Given** the `outcalld` daemon is running and `outcall-default` network exists
**And** the image `my-agent:latest` is available locally
**When** the user runs `outcall container create --image my-agent:latest`
**Then** `outcalld` creates and starts a Docker container with:
  - name: `outcall-<8-hex>` (e.g. `outcall-a3f7b201`)
  - network: `outcall-default`
  - bind mount: `agent.sock` at `/run/outcall/agent.sock` (read-only)
  - bind mount: shim at `/usr/local/bin/outcall` (read-only)
  - env: `HTTP_PROXY=http://<proxy-addr>`, `HTTPS_PROXY=http://<proxy-addr>`
  - DNS: set to DNS filter address
  - Docker network mode: `outcall-default`
  - init: enabled
  - label: `managed-by=outcalld`
**And** the CLI prints `Container "outcall-a3f7b201" created and started.`
**And** the command exits with code 0.

### S008-AS-002 Create: host socket in bind mounts rejected [P1]

**Given** the `outcalld` daemon is running
**When** an API call attempts to bind the host API socket, Docker socket, a symlink to either, or a parent directory exposing either
**Then** `outcalld` rejects the request before calling the Docker API
**And** the error identifies the bind source and protected path
**And** no container is created.

### S008-AS-003 List: running containers [P1]

**Given** the `outcalld` daemon is running
**And** two agent containers are running: `outcall-a3f7b201` and `outcall-c4d8e502`
**When** the user runs `outcall container list`
**Then** the CLI prints a table of all outcall-managed containers with name, image, state, network, and creation time
**And** the command exits with code 0.

### S008-AS-004 Stop: running container [P1]

**Given** the `outcalld` daemon is running
**And** container `outcall-a3f7b201` is running
**When** the user runs `outcall container stop --name outcall-a3f7b201`
**Then** `outcalld` sends SIGTERM and waits up to 10 seconds
**And** the CLI prints `Container "outcall-a3f7b201" stopped.`
**And** the command exits with code 0.

### S008-AS-005 Remove: stopped container [P1]

**Given** the `outcalld` daemon is running
**And** container `outcall-a3f7b201` is stopped
**When** the user runs `outcall container remove --name outcall-a3f7b201`
**Then** `outcalld` removes the container
**And** the CLI prints `Container "outcall-a3f7b201" removed.`
**And** the command exits with code 0.

### S008-AS-006 Create: network not ready [P1]

**Given** the `outcalld` daemon is running
**And** no outcall-managed network exists
**When** the user runs `outcall container create --image my-agent:latest`
**Then** the API returns an error identifying the missing or invalid network
**And** the command exits with code 1.

### S008-AS-007 Inspect: container details [P2]

**Given** the `outcalld` daemon is running
**And** container `outcall-a3f7b201` is running
**When** the user runs `outcall container inspect --name outcall-a3f7b201`
**Then** the CLI prints the container's ID, name, image, state, network, IP address, bind mounts, environment variable names with redacted values, and creation time
**And** the command exits with code 0.

### S008-AS-008 Pull: image from registry [P2]

**Given** the `outcalld` daemon is running
**And** the image `my-agent:latest` is not available locally
**When** the user runs `outcall container pull --image my-agent:latest`
**Then** `outcalld` pulls the image from the registry
**And** the CLI prints `Image "my-agent:latest" pulled.`
**And** the command exits with code 0.

### S008-AS-009 Daemon not running [P1]

**Given** the `outcalld` daemon is not running
**When** the user runs any `outcall container` subcommand
**Then** the CLI prints `Error: cannot connect to outcalld at <socket> -- is it running?`
**And** the command exits with code 1.

### S008-AS-010 Docker not available [P1]

**Given** the `outcalld` daemon is running
**And** the Docker Engine is not reachable
**When** the user runs `outcall container create --image my-agent:latest`
**Then** the API returns an error indicating Docker is unavailable
**And** the command exits with code 1.

### S008-AS-011 Graceful shutdown: containers survive [P1]

**Given** the `outcalld` daemon is running
**And** three agent containers are running
**When** `outcalld` receives SIGTERM
**Then** `outcalld` shuts down without stopping or removing agent containers
**And** all three containers remain running
**And** when `outcalld` restarts, it rediscovers them by `managed-by=outcalld` label.

### S008-AS-012 Create: container with resource limits [P1]

**Given** the `outcalld` daemon is running and `outcall-default` network exists
**When** the user runs `outcall container create --image my-agent:latest --memory 256m --cpu-shares 512`
**Then** the container is created with a 256 MiB memory limit and 512 CPU shares
**And** the command exits with code 0.

### S008-AS-013 Verify: bind mounts inside container [P1]

**Given** an agent container created with helper mounts enabled is running
**When** a process inside the container checks `/usr/local/bin/outcall`
**Then** the shim binary is present and executable
**And** when a process checks `/run/outcall/agent.sock`
**Then** the agent socket is present
**And** there is no path to the host socket from inside the container.

### S008-AS-014 Verify: env vars inside container [P1]

**Given** an agent container created by `outcalld` is running
**When** a process inside the container reads `HTTP_PROXY`
**Then** it contains the HTTP proxy address
**And** when a process reads `HTTPS_PROXY`
**Then** it contains the HTTP proxy address
**And** when a process reads the DNS resolver configuration
**Then** it points at the DNS filter address.

### S008-AS-015 Create: protected container destination rejected [P1]

**Given** helper mounts or daemon-managed DNS are enabled
**When** a caller-provided mount targets a control path or a parent directory covering it
**Then** `outcalld` rejects the request before calling Docker
**And** the existing shim, agent socket, and resolver configuration cannot be shadowed.

### S008-AS-016 Lifecycle: unmanaged container rejected [P1]

**Given** a Docker container exists without `managed-by=outcalld`
**When** an operator calls Outcall inspect, stop, or remove for its name
**Then** the operation is rejected
**And** the unmanaged container remains unchanged.

### S008-AS-017 Startup: Docker client exists but engine hangs [P1]

**Given** the Docker endpoint can be opened but `_ping` does not finish
**When** `outcalld` initializes the Docker Manager
**Then** initialization waits no more than 3 seconds
**And** the manager reports degraded mode
**And** the policy daemon continues running.

### S008-AS-018 Create: partial container rollback [P1]

**Given** Docker creates a container but start or identity registration fails
**When** the create request completes
**Then** `outcalld` force-removes the partial container and anonymous volumes
**And** returns the original failure
**And** includes any rollback failure in the same error.

### S008-AS-019 Pull: registry port and digest [P2]

**Given** an image uses `registry.example:5000/team/agent:dev` or an OCI digest
**When** the image is pulled
**Then** the registry port, repository, tag, and digest are sent to Docker without misparsing.
