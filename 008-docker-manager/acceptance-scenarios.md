# S008 Acceptance Scenarios

### S008-AS-001 Create: agent container with all constraints [P1]

**Given** the `outcalld` daemon is running and `outcall-default` network exists
**And** the image `my-agent:latest` is available locally
**When** the user runs `outcall container create --image my-agent:latest`
**Then** `outcalld` creates and starts a Docker container with:
  - name: `outcall-agent-<8-hex>` (e.g. `outcall-agent-a3f7b201`)
  - network: `outcall-default`
  - bind mount: `agent.sock` at `/run/outcall/agent.sock` (read-only)
  - bind mount: shim at `/usr/local/bin/outcall` (read-only)
  - env: `HTTP_PROXY=http://<proxy-addr>`, `HTTPS_PROXY=http://<proxy-addr>`
  - DNS: set to DNS filter address
  - label: `managed-by=outcalld`
**And** the CLI prints `Container "outcall-agent-a3f7b201" created and started.`
**And** the command exits with code 0.

### S008-AS-002 Create: host socket in bind mounts rejected [P1]

**Given** the `outcalld` daemon is running
**When** an internal or API call attempts to create a container with the host socket path in a bind mount
**Then** `outcalld` rejects the request before calling the Docker API
**And** the error message reads `Error: bind mount denied — "<host-sock-path>" is on the deny list`
**And** no container is created.

### S008-AS-003 List: running containers [P1]

**Given** the `outcalld` daemon is running
**And** two agent containers are running: `outcall-agent-a3f7b201` and `outcall-agent-c4d8e502`
**When** the user runs `outcall container list`
**Then** the CLI prints a table of all outcall-managed containers with name, image, state, network, and creation time
**And** the command exits with code 0.

### S008-AS-004 Stop: running container [P1]

**Given** the `outcalld` daemon is running
**And** container `outcall-agent-a3f7b201` is running
**When** the user runs `outcall container stop --name outcall-agent-a3f7b201`
**Then** `outcalld` sends SIGTERM and waits up to 10 seconds
**And** the CLI prints `Container "outcall-agent-a3f7b201" stopped.`
**And** the command exits with code 0.

### S008-AS-005 Remove: stopped container [P1]

**Given** the `outcalld` daemon is running
**And** container `outcall-agent-a3f7b201` is stopped
**When** the user runs `outcall container remove --name outcall-agent-a3f7b201`
**Then** `outcalld` removes the container
**And** the CLI prints `Container "outcall-agent-a3f7b201" removed.`
**And** the command exits with code 0.

### S008-AS-006 Create: network not ready [P1]

**Given** the `outcalld` daemon is running
**And** no outcall-managed network exists
**When** the user runs `outcall container create --image my-agent:latest`
**Then** the API returns an error
**And** the CLI prints `Error: network "outcall-default" does not exist — run "outcall network create" first`
**And** the command exits with code 1.

### S008-AS-007 Inspect: container details [P2]

**Given** the `outcalld` daemon is running
**And** container `outcall-agent-a3f7b201` is running
**When** the user runs `outcall container inspect --name outcall-agent-a3f7b201`
**Then** the CLI prints the container's ID, name, image, state, network, IP address, bind mounts, environment variables, and creation time
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
**And** when `outcalld` restarts, it rediscovers them by name prefix.

### S008-AS-012 Create: container with resource limits [P1]

**Given** the `outcalld` daemon is running and `outcall-default` network exists
**When** the user runs `outcall container create --image my-agent:latest --memory 256m --cpu-shares 512`
**Then** the container is created with a 256 MiB memory limit and 512 CPU shares
**And** the command exits with code 0.

### S008-AS-013 Verify: bind mounts inside container [P1]

**Given** an agent container created by `outcalld` is running
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
