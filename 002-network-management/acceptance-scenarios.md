# S002 Acceptance Scenarios

### S002-AS-001 Create: default network [P1]

**Given** the `outcalld` daemon is running and the bridge is up
**And** no network named `outcall-default` exists
**When** the user runs `outcall network create`
**Then** `outcalld` creates a Docker bridge network with:
  - name: `outcall-default`
  - driver: `bridge`
  - subnet: `10.200.0.0/24`
  - gateway: `10.200.0.1`
  - bridge option `com.docker.network.bridge.name` set to `outcall0`
**And** the CLI prints `Network "outcall-default" created.`
**And** the command exits with code 0.

### S002-AS-002 Create: named network (auto-subnet) [P1]

**Given** the `outcalld` daemon is running and the bridge is up
**And** `10.200.0.0/24` is already allocated to `outcall-default`
**When** the user runs `outcall network create --name staging`
**Then** `outcalld` auto-allocates the next available `/24` (e.g. `10.200.1.0/24`)
**And** creates a Docker bridge network with:
  - name: `outcall-staging`
  - driver: `bridge`
  - subnet: `10.200.1.0/24`
  - gateway: `10.200.1.1`
  - bridge option `com.docker.network.bridge.name` set to `outcall0`
**And** the CLI prints `Network "outcall-staging" created (10.200.1.0/24).`
**And** the command exits with code 0.

### S002-AS-003 Create: network already exists [P1]

**Given** the `outcalld` daemon is running
**And** a network named `outcall-default` already exists
**When** the user runs `outcall network create`
**Then** the API returns success with `created: false`
**And** the CLI prints `Network "outcall-default" already exists.`
**And** the command exits with code 0.

### S002-AS-004 Create: bridge not up [P1]

**Given** the `outcalld` daemon is running
**And** the bridge has not been initialized
**When** the user runs `outcall network create`
**Then** the API returns an error
**And** the CLI prints `Error: bridge is not up — run "outcall bridge up" first`
**And** the command exits with code 1.

### S002-AS-005 Status: network exists with containers [P1]

**Given** the `outcalld` daemon is running
**And** the network `outcall-default` exists with two connected containers
**When** the user runs `outcall network status`
**Then** the CLI prints the network name, subnet, gateway, and a list of connected containers (name and IP address)
**And** the command exits with code 0.

### S002-AS-006 Status: named network [P1]

**Given** the `outcalld` daemon is running
**And** a network named `outcall-staging` exists
**When** the user runs `outcall network status --name staging`
**Then** the CLI prints the status for `outcall-staging`
**And** the command exits with code 0.

### S002-AS-007 Status: network does not exist [P1]

**Given** the `outcalld` daemon is running
**And** no network named `outcall-default` exists
**When** the user runs `outcall network status`
**Then** the CLI prints `Network "outcall-default" does not exist.`
**And** the command exits with code 0.

### S002-AS-008 List: multiple networks [P1]

**Given** the `outcalld` daemon is running
**And** networks `outcall-default` and `outcall-staging` both exist
**When** the user runs `outcall network list`
**Then** the CLI prints a table of all outcall-managed networks with their names, subnets, and container counts
**And** the command exits with code 0.

### S002-AS-009 Destroy: named network [P1]

**Given** the `outcalld` daemon is running
**And** a network named `outcall-staging` exists with no containers
**When** the user runs `outcall network destroy --name staging`
**Then** `outcalld` removes the network
**And** the CLI prints `Network "outcall-staging" destroyed.`
**And** the command exits with code 0.

### S002-AS-010 Destroy: default network [P1]

**Given** the `outcalld` daemon is running
**And** the network `outcall-default` exists with no containers
**When** the user runs `outcall network destroy`
**Then** `outcalld` removes the network
**And** the CLI prints `Network "outcall-default" destroyed.`
**And** the command exits with code 0.
**And** running `outcall network create` afterward recreates it.

### S002-AS-011 Destroy: containers still connected [P1]

**Given** the `outcalld` daemon is running
**And** a network named `outcall-staging` exists with containers connected
**When** the user runs `outcall network destroy --name staging`
**Then** the API returns an error listing the connected container names
**And** the command exits with code 1.

### S002-AS-012 Destroy: network does not exist [P2]

**Given** the `outcalld` daemon is running
**And** no network named `outcall-staging` exists
**When** the user runs `outcall network destroy --name staging`
**Then** the API returns success (idempotent)
**And** the CLI prints `Network "outcall-staging" does not exist (nothing to destroy).`
**And** the command exits with code 0.

### S002-AS-013 Daemon not running [P1]

**Given** the `outcalld` daemon is not running
**When** the user runs any `outcall network` subcommand
**Then** the CLI prints `Error: cannot connect to outcalld at <socket> -- is it running?`
**And** the command exits with code 1.

### S002-AS-014 Docker not available [P1]

**Given** the `outcalld` daemon is running
**And** the Docker Engine is not reachable
**When** the user runs `outcall network create`
**Then** the API returns an error indicating Docker is unavailable
**And** the command exits with code 1.
