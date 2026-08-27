# S004 Interface Requirements

All endpoints are served on the agent Unix socket (`/run/outcall/agent.sock`).
Content-Type is `application/json` for all requests and responses.

---

### S004-IF-001 POST /v1/checkin [P1]

Register the agent and receive identity and session context. The agent sends an empty body; `outcalld` derives the container identity from the Unix socket peer credentials (`SO_PEERCRED`) and maps it to Docker metadata.

**Request body**:

```json
{}
```

No agent-supplied fields. Identity is derived entirely host-side from the calling process's peer credentials.

**Success response** (200):

```json
{
  "success": true,
  "data": {
    "container_id": "ctr-a1b2c3d4",
    "session_token": "tok-e5f6g7h8i9j0k1l2",
    "context_keys": ["action_type", "target", "metadata"]
  }
}
```

**Error response** (403 -- unknown container):

```json
{
  "success": false,
  "error": "check-in rejected: peer PID 12345 does not belong to a known container"
}
```

---

### S004-IF-002 POST /v1/permissions/check [P1]

Request a verdict before executing an action. The session token **MUST** be sent in the `Authorization` header as `Bearer <token>`.

**Request body**:

```json
{
  "action_type": "tool_exec",
  "target": "read_file",
  "metadata": {
    "path": "/workspace/config.yaml",
    "mode": "read"
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `action_type` | string | Yes | One of: `tool_exec`, `network_call`, `file_access`, `shell_exec` |
| `target` | string | Yes | The specific resource (tool name, URL, file path, command) |
| `metadata` | object | No | Arbitrary key-value pairs for rule matching context |

**Success response** (200 -- allowed):

```json
{
  "success": true,
  "data": {
    "allowed": true,
    "matched_rule": "rule-7f8e9d",
    "reason": null
  }
}
```

**Success response** (200 -- denied):

```json
{
  "success": true,
  "data": {
    "allowed": false,
    "matched_rule": null,
    "reason": "no rule allows network_call to evil.example.com"
  }
}
```

**Error response** (401 -- missing or invalid token):

```json
{
  "success": false,
  "error": "invalid or missing session token"
}
```

**Error response** (429 -- rate limited):

```json
{
  "success": false,
  "error": "rate limit exceeded for container ctr-a1b2c3d4"
}
```

Header: `Retry-After: 2`

---

### S004-IF-003 POST /v1/requests/rules [P2]

Submit a rule request for host operator approval. Requires `Bearer <token>` authorization. The body **MUST** contain a complete, valid rule file in the S003 YAML format (S003-IF-012). `outcalld` parses and validates the file before queuing; invalid files are rejected immediately.

**Request body**:

```json
{
  "rule_file": "version: \"1\"\nrules:\n  - id: allow-workspace-read\n    condition: \"action_type == 'file_access' && target.startsWith('/workspace')\"\n    action: allow\n    description: Allow read access to /workspace directory"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `rule_file` | string | Yes | Complete S003-format YAML rule file (S003-IF-012). Must parse and validate successfully. |

**Success response** (201):

```json
{
  "success": true,
  "data": {
    "id": "rr-abc123",
    "status": "pending",
    "reason": null
  }
}
```

**Error response** (422 -- invalid rule file):

```json
{
  "success": false,
  "error": "invalid rule file: YAML parse error at line 3: unexpected token"
}
```

---

### S004-IF-004 GET /v1/requests/rules/{id} [P2]

Query the status of a previously submitted rule request. Requires `Bearer <token>` authorization.

**Success response** (200 -- pending):

```json
{
  "success": true,
  "data": {
    "id": "rr-abc123",
    "status": "pending",
    "reason": null
  }
}
```

**Success response** (200 -- approved):

```json
{
  "success": true,
  "data": {
    "id": "rr-abc123",
    "status": "approved",
    "reason": "operator approved at 2026-04-21T14:30:00Z"
  }
}
```

**Success response** (200 -- rejected):

```json
{
  "success": true,
  "data": {
    "id": "rr-abc123",
    "status": "rejected",
    "reason": "policy does not permit filesystem write rules for this container"
  }
}
```

**Error response** (404 -- unknown request ID):

```json
{
  "success": false,
  "error": "rule request rr-xyz789 not found"
}
```

**Error response** (403 -- request belongs to another container):

```json
{
  "success": false,
  "error": "rule request rr-abc123 not found"
}
```

Note: a 403 for cross-container access **MUST** return the same 404-style message to avoid confirming the existence of another container's request.

---

### S004-IF-005 Error response format [P1]

All error responses **MUST** use the `ApiResponse` envelope:

```json
{
  "success": false,
  "error": "human-readable error message"
}
```

HTTP status codes used by the agent API:

| Code | Meaning |
|------|---------|
| 200 | Success (including deny verdicts -- the request succeeded, the action was denied) |
| 201 | Rule request created |
| 400 | Malformed request body |
| 401 | Missing or invalid session token |
| 403 | Check-in rejected (unknown container) |
| 404 | Rule request not found |
| 413 | Request body too large |
| 422 | Invalid condition syntax in rule request |
| 429 | Rate limit exceeded |
| 500 | Internal server error |
| 503 | Peer identity lookup timed out or session capacity reached |
