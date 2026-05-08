# S002 Interface Requirements

### S002-IF-001 POST /api/v1/network/create [P1]

Create a network.

**Request body**:

```json
{
  "name": "staging",
  "subnet": "10.200.5.0/24",
  "gateway": "10.200.5.1"
}
```

All fields are optional. If `name` is omitted, the default network is created.
If `subnet` is omitted, it is auto-allocated from the `10.200.0.0/16` block.

**Success response** (`ApiResponse<NetworkCreateResult>`):

```json
{
  "success": true,
  "data": {
    "network_id": "a1b2c3d4...",
    "name": "outcall-staging",
    "created": true
  }
}
```

When the network already exists, `created` is `false`.

### S002-IF-002 GET /api/v1/network?name=\<name\> [P1]

Query a single network's status. If `name` is omitted, returns the default network.

**Success response** (`ApiResponse<NetworkStatus>`):

```json
{
  "success": true,
  "data": {
    "exists": true,
    "network_id": "a1b2c3d4...",
    "name": "outcall-default",
    "subnet": "10.200.0.0/24",
    "gateway": "10.200.0.1",
    "containers": [
      { "name": "my-agent", "ipv4_address": "10.200.0.2" }
    ]
  }
}
```

When the network does not exist, `exists` is `false` and other fields are null/empty.

### S002-IF-003 GET /api/v1/networks [P1]

List all outcall-managed networks.

**Success response** (`ApiResponse<Vec<NetworkStatus>>`):

```json
{
  "success": true,
  "data": [
    {
      "exists": true,
      "network_id": "a1b2...",
      "name": "outcall-default",
      "subnet": "10.200.0.0/24",
      "gateway": "10.200.0.1",
      "containers": [
        { "name": "my-agent", "ipv4_address": "10.200.0.2" }
      ]
    },
    {
      "exists": true,
      "network_id": "e5f6...",
      "name": "outcall-staging",
      "subnet": "10.200.1.0/24",
      "gateway": "10.200.1.1",
      "containers": []
    }
  ]
}
```

### S002-IF-004 POST /api/v1/network/destroy [P1]

Remove a network.

**Request body**:

```json
{ "name": "staging" }
```

If `name` is omitted, targets the default network.

**Success response** (`ApiResponse<NetworkDestroyResult>`):

```json
{ "success": true, "data": { "name": "outcall-staging", "destroyed": true } }
```

**Error response** (containers connected):

```json
{ "success": false, "error": "cannot destroy network \"outcall-staging\": 2 containers still connected: my-agent, other-agent" }
```

### S002-IF-005 CLI commands [P1]

```
outcall network create                                          # create outcall-default
outcall network create --name staging                           # create outcall-staging (auto-subnet)
outcall network create --name prod --subnet 10.200.50.0/24      # create outcall-prod (explicit subnet)
outcall network status                                          # outcall-default status
outcall network status --name staging                           # outcall-staging status
outcall network list                                            # list all outcall-* networks
outcall network destroy --name staging                          # destroy outcall-staging
outcall network destroy                                         # destroy outcall-default (recreatable)
```

All commands accept the global `--socket <path>` flag.

### S002-IF-006 CLI output format [P1]

**`outcall network create`** (new):
```
Network "outcall-default" created.
```

**`outcall network create --name staging`** (new, auto-allocated):
```
Network "outcall-staging" created (10.200.1.0/24).
```

**`outcall network status`** (with containers):
```
Network:      outcall-default
Status:       active
Subnet:       10.200.0.0/24
Gateway:      10.200.0.1
Containers:   2
  my-agent         10.200.0.2
  other-agent      10.200.0.3
```

**`outcall network list`**:
```
NAME               SUBNET           CONTAINERS
outcall-default    10.200.0.0/24    2
outcall-staging    10.200.1.0/24    0
```

**`outcall network destroy`** (success):
```
Network "outcall-default" destroyed.
```

**`outcall network destroy --name staging`** (success):
```
Network "outcall-staging" destroyed.
```

All error output goes to stderr. Exit code 1 on error, 0 on success.
