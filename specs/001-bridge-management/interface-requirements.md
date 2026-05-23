# S001 Interface Requirements

### S001-IF-001 GET /api/v1/bridge [P1]

Query bridge status. Fresh check every call (netlink + nft).

**Success response** (`ApiResponse<BridgeStatus>`):

```json
{
  "success": true,
  "data": {
    "name": "outcall0",
    "up": true,
    "index": 42,
    "nftables_active": true
  }
}
```

When the bridge is down, `up` is `false`, `index` is `null`, `nftables_active` is `false`.

### S001-IF-002 POST /api/v1/bridge/up [P1]

Initialize bridge and apply nftables rules. Idempotent.

**Request body**: none (Content-Length: 0).

**Success response**:

```json
{ "success": true }
```

**Error response**:

```json
{ "success": false, "error": "bridge operation failed: create bridge: Operation not permitted" }
```

### S001-IF-003 POST /api/v1/bridge/down [P1]

Tear down bridge and remove nftables rules.

**Request body**: none (Content-Length: 0).

**Success response**:

```json
{ "success": true }
```

### S001-IF-004 CLI commands [P1]

```
outcall bridge status    # show bridge name, state, nftables status
outcall bridge up        # initialize bridge + apply nftables rules
outcall bridge down      # tear down bridge + remove nftables rules
```

All commands accept the global `--socket <path>` flag (default: `/run/outcall/host.sock`).

### S001-IF-005 CLI output format [P1]

**`outcall bridge status`** (up):
```
Bridge:    outcall0
Status:    up
Index:     42
nftables:  active
```

**`outcall bridge status`** (down):
```
Bridge:    outcall0
Status:    down
nftables:  inactive
```

**`outcall bridge up`** (success):
```
Bridge is up.
```

**`outcall bridge down`** (success):
```
Bridge is down.
```

### S001-IF-006 Host socket protocol [P1]

The host API uses HTTP/1.1 served by axum over a Unix domain socket. The socket path defaults to `/run/outcall/host.sock`.

All responses use the `ApiResponse<T>` JSON envelope:

```json
{ "success": true, "data": { ... } }
{ "success": false, "error": "message" }
```

### S001-IF-007 CLI transport protocol [P1]

The `outcall` CLI sends HTTP/1.0 requests over the unix socket using synchronous blocking I/O (`std::os::unix::net::UnixStream`). HTTP/1.0 is used because the server closes the connection after the response, allowing the CLI to `read_to_string` without needing to parse `Content-Length` or chunked encoding.

Request format:
```
GET /api/v1/bridge HTTP/1.0\r\n
Host: localhost\r\n
\r\n
```

For POST:
```
POST /api/v1/bridge/up HTTP/1.0\r\n
Host: localhost\r\n
Content-Length: 0\r\n
\r\n
```

The CLI extracts the response body by splitting on `\r\n\r\n` and parsing the remainder as JSON.

### S001-IF-008 outcalld CLI flags [P1]

```
outcalld                             # start with defaults
outcalld --bridge outcall0           # specify bridge name
outcalld --socket /tmp/out.sock      # custom socket path
```

| Flag | Default | Description |
|------|---------|-------------|
| `--bridge` | `outcall0` | Bridge interface name |
| `--socket` | `/run/outcall/host.sock` | Host API socket path |
