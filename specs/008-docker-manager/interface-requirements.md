# S008 Interface Requirements

### S008-IF-001 POST /api/v1/container/create [P1]

Create and start an agent container with security constraints enforced.

**Request body**:

```json
{
  "image": "my-agent:latest",
  "network": "staging",
  "name": "my-task",
  "memory_limit": 268435456,
  "cpu_shares": 512,
  "env": ["MY_VAR=value"],
  "cmd": ["/bin/sh", "-c", "run-agent"]
}
```

Only `image` is required. If `network` is omitted, the default network (`outcall-default`) is used. If `name` is omitted, an 8-character hex suffix is generated. The `outcall-agent-` prefix is always prepended. Additional `env` entries are merged with the mandatory proxy/DNS env vars. `memory_limit` is in bytes. `cmd` overrides the image's default command.

**Success response** (`ApiResponse<ContainerCreateResult>`):

```json
{
  "success": true,
  "data": {
    "container_id": "sha256:a1b2c3d4...",
    "name": "outcall-agent-my-task",
    "created": true
  }
}
```

**Error response** (host socket denied):

```json
{ "success": false, "error": "bind mount denied — \"/run/outcall/host.sock\" is on the deny list" }
```

**Error response** (network missing):

```json
{ "success": false, "error": "network \"outcall-default\" does not exist" }
```

### S008-IF-002 POST /api/v1/container/stop [P1]

Stop a running container.

**Request body**:

```json
{
  "name": "outcall-agent-a3f7b201",
  "timeout": 15
}
```

`timeout` is optional (default: 10 seconds). Specifies how long to wait after SIGTERM before SIGKILL.

**Success response** (`ApiResponse<ContainerStopResult>`):

```json
{ "success": true, "data": { "name": "outcall-agent-a3f7b201", "stopped": true } }
```

**Error response** (not running):

```json
{ "success": false, "error": "container \"outcall-agent-a3f7b201\" is not running" }
```

### S008-IF-003 POST /api/v1/container/remove [P1]

Remove a stopped container.

**Request body**:

```json
{
  "name": "outcall-agent-a3f7b201",
  "force": false
}
```

`force` is optional (default: `false`). If `true`, a running container is stopped first.

**Success response** (`ApiResponse<ContainerRemoveResult>`):

```json
{ "success": true, "data": { "name": "outcall-agent-a3f7b201", "removed": true } }
```

**Error response** (still running):

```json
{ "success": false, "error": "container \"outcall-agent-a3f7b201\" is still running — stop it first or use force" }
```

### S008-IF-004 GET /api/v1/containers [P1]

List all outcall-managed containers.

**Success response** (`ApiResponse<Vec<ContainerInfo>>`):

```json
{
  "success": true,
  "data": [
    {
      "container_id": "a1b2c3d4...",
      "name": "outcall-agent-a3f7b201",
      "image": "my-agent:latest",
      "state": "running",
      "network": "outcall-default",
      "created_at": "2026-04-21T14:30:00Z"
    },
    {
      "container_id": "e5f6g7h8...",
      "name": "outcall-agent-c4d8e502",
      "image": "my-agent:latest",
      "state": "exited",
      "network": "outcall-default",
      "created_at": "2026-04-21T14:25:00Z"
    }
  ]
}
```

### S008-IF-005 GET /api/v1/container?name=\<name\> [P2]

Inspect a single container.

**Success response** (`ApiResponse<ContainerInspectResult>`):

```json
{
  "success": true,
  "data": {
    "container_id": "a1b2c3d4...",
    "name": "outcall-agent-a3f7b201",
    "image": "my-agent:latest",
    "state": "running",
    "network": "outcall-default",
    "ip_address": "10.200.0.2",
    "mounts": [
      "/run/outcall/agent.sock:/run/outcall/agent.sock:ro",
      "/usr/local/bin/outcall-agent:/usr/local/bin/outcall:ro"
    ],
    "env": [
      "HTTP_PROXY=http://10.200.0.1:8080",
      "HTTPS_PROXY=http://10.200.0.1:8080",
      "NO_PROXY=localhost,127.0.0.1"
    ],
    "created_at": "2026-04-21T14:30:00Z"
  }
}
```

**Error response** (not found):

```json
{ "success": false, "error": "container \"outcall-agent-xyz\" does not exist" }
```

### S008-IF-006 POST /api/v1/container/pull [P2]

Pull an image from a registry.

**Request body**:

```json
{ "image": "my-agent:latest" }
```

**Success response** (`ApiResponse<ImagePullResult>`):

```json
{ "success": true, "data": { "image": "my-agent:latest", "pulled": true } }
```

If the image is already present and up-to-date, `pulled` is `false`.

**Error response** (pull failed):

```json
{ "success": false, "error": "failed to pull image \"my-agent:latest\": not found" }
```

### S008-IF-007 CLI commands [P1]

```
outcall container create --image my-agent:latest                              # create on outcall-default
outcall container create --image my-agent:latest --network staging            # create on outcall-staging
outcall container create --image my-agent:latest --name my-task               # create with custom suffix
outcall container create --image my-agent:latest --memory 256m --cpu-shares 512
outcall container list                                                        # list all agent containers
outcall container inspect --name outcall-agent-a3f7b201                       # inspect single container
outcall container stop --name outcall-agent-a3f7b201                          # stop container
outcall container stop --name outcall-agent-a3f7b201 --timeout 30             # stop with custom timeout
outcall container remove --name outcall-agent-a3f7b201                        # remove stopped container
outcall container remove --name outcall-agent-a3f7b201 --force                # force remove running container
outcall container pull --image my-agent:latest                                # pull image
```

All commands accept the global `--socket <path>` flag.

### S008-IF-008 CLI output format [P1]

**`outcall container create`** (success):
```
Container "outcall-agent-a3f7b201" created and started.
```

**`outcall container list`** (with containers):
```
NAME                       IMAGE              STATE     NETWORK           CREATED
outcall-agent-a3f7b201     my-agent:latest    running   outcall-default   2026-04-21T14:30:00Z
outcall-agent-c4d8e502     my-agent:latest    exited    outcall-default   2026-04-21T14:25:00Z
```

**`outcall container list`** (no containers):
```
No agent containers found.
```

**`outcall container inspect`**:
```
Container:    outcall-agent-a3f7b201
ID:           a1b2c3d4...
Image:        my-agent:latest
State:        running
Network:      outcall-default
IP Address:   10.200.0.2
Mounts:
  /run/outcall/agent.sock:/run/outcall/agent.sock:ro
  /usr/local/bin/outcall-agent:/usr/local/bin/outcall:ro
Environment:
  HTTP_PROXY=http://10.200.0.1:8080
  HTTPS_PROXY=http://10.200.0.1:8080
  NO_PROXY=localhost,127.0.0.1
Created:      2026-04-21T14:30:00Z
```

**`outcall container stop`** (success):
```
Container "outcall-agent-a3f7b201" stopped.
```

**`outcall container remove`** (success):
```
Container "outcall-agent-a3f7b201" removed.
```

**`outcall container pull`** (success):
```
Image "my-agent:latest" pulled.
```

All error output goes to stderr. Exit code 1 on error, 0 on success.
