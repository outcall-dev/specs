# S003 Interface Requirements

### S003-IF-001 POST /api/v1/rule/evaluate [P1]

Evaluate a request against the loaded rule set. This is an internal endpoint called by `outcalld` subsystems (bridge, network interceptors) -- not directly by agents.

**Request body**:

```json
{
  "context": {
    "network": {
      "hostname": "github.com",
      "ip": "140.82.121.4",
      "port": 443,
      "protocol": "tcp"
    },
    "http": {
      "method": "GET",
      "path": "/api/v3/repos",
      "host": "github.com",
      "headers": { "authorization": "token xxx" },
      "body_size": 0
    }
  }
}
```

Only the relevant context namespaces need to be populated. Omitted namespaces are treated as absent -- rules referencing absent namespace variables evaluate to false for that condition.

**Success response** (`ApiResponse<EvaluateResult>`):

```json
{
  "success": true,
  "data": {
    "decision": "allow",
    "matched_rule": "allow-github-api",
    "file": "00-base.yaml",
    "logged": false
  }
}
```

When no rule matches (default block):

```json
{
  "success": true,
  "data": {
    "decision": "block",
    "matched_rule": null,
    "file": null,
    "logged": false
  }
}
```

**Error response** (bridge not up):

```json
{
  "success": false,
  "error": "rule evaluation unavailable: bridge is not up"
}
```

### S003-IF-002 GET /api/v1/rules [P1]

List all loaded rules across all files.

**Success response** (`ApiResponse<Vec<RuleSummary>>`):

```json
{
  "success": true,
  "data": [
    {
      "id": "allow-github-api",
      "file": "00-base.yaml",
      "action": "allow",
      "condition_preview": "$is_github && http.path.startsWith(\"/api/v3\")",
      "description": "Allow GitHub API v3 access"
    },
    {
      "id": "block-force-push",
      "file": "00-base.yaml",
      "action": "block",
      "condition_preview": "run.tool == \"git\" && \"-f\" in run.flags",
      "description": null
    }
  ]
}
```

Rules are returned in evaluation order (filename sort, then position within file).

### S003-IF-003 GET /api/v1/rule/:id [P1]

Get details for a specific rule by ID.

**Success response** (`ApiResponse<Rule>`):

```json
{
  "success": true,
  "data": {
    "id": "allow-github-api",
    "condition": "network.hostname == \"github.com\" && http.method in [\"GET\", \"POST\"] && http.path.startsWith(\"/api/v3\")",
    "action": "allow",
    "log": false,
    "description": "Allow GitHub API v3 access",
    "enrich": null
  }
}
```

The `condition` field shows the fully expanded expression (definitions resolved).

**Error response** (rule not found):

```json
{
  "success": false,
  "error": "rule not found: \"nonexistent-id\""
}
```

### S003-IF-004 POST /api/v1/rules/reload [P2]

Trigger a rule reload from disk.

**Request body**: none

**Success response** (`ApiResponse<ReloadResult>`):

```json
{
  "success": true,
  "data": {
    "files_loaded": 3,
    "rules_loaded": 12,
    "warnings": ["unused definition \"legacy_var\" in 50-custom.yaml"]
  }
}
```

**Error response** (validation failure):

```json
{
  "success": false,
  "error": "reload failed: CEL parse error in 50-custom.yaml rule \"bad-rule\": unexpected token at position 15. Previous rules remain active."
}
```

### S003-IF-005 POST /api/v1/rule/test [P2]

Evaluate a CEL expression against a provided context without affecting actual traffic.

**Request body**:

```json
{
  "expression": "network.hostname == \"github.com\" && http.method == \"GET\"",
  "context": {
    "network": {
      "hostname": "github.com",
      "ip": "140.82.121.4",
      "port": 443,
      "protocol": "tcp"
    },
    "http": {
      "method": "GET",
      "path": "/",
      "host": "github.com",
      "headers": {},
      "body_size": 0
    }
  }
}
```

**Success response** (`ApiResponse<TestExpressionResult>`):

```json
{
  "success": true,
  "data": {
    "result": true,
    "error": null
  }
}
```

**Error response** (invalid expression):

```json
{
  "success": true,
  "data": {
    "result": false,
    "error": "CEL parse error: unexpected token at position 10"
  }
}
```

### S003-IF-006 POST /api/v1/agent/rule-request [P3]

Submit a rule request from an agent. This is the **only** rule engine endpoint exposed on the agent-facing socket.

**Request body**:

```json
{
  "description": "Need access to PyPI for package installation",
  "requested_access": "HTTPS to pypi.org",
  "suggested_condition": "network.hostname == \"pypi.org\" && http.method == \"GET\""
}
```

`suggested_condition` is optional.

**Success response** (`ApiResponse<RuleRequest>`):

```json
{
  "success": true,
  "data": {
    "id": "req-a1b2c3",
    "submitted_at": "2026-04-21T14:30:00Z",
    "status": "pending",
    "description": "Need access to PyPI for package installation",
    "requested_access": "HTTPS to pypi.org",
    "suggested_condition": "network.hostname == \"pypi.org\" && http.method == \"GET\""
  }
}
```

### S003-IF-007 GET /api/v1/rule-requests [P2]

List all rule requests. Host-only endpoint.

**Query parameters**:
- `status` (optional): filter by `pending`, `approved`, or `denied`

**Success response** (`ApiResponse<Vec<RuleRequest>>`):

```json
{
  "success": true,
  "data": [
    {
      "id": "req-a1b2c3",
      "submitted_at": "2026-04-21T14:30:00Z",
      "status": "pending",
      "description": "Need access to PyPI for package installation",
      "requested_access": "HTTPS to pypi.org",
      "suggested_condition": "network.hostname == \"pypi.org\" && http.method == \"GET\""
    }
  ]
}
```

### S003-IF-008 POST /api/v1/rule-request/:id/approve [P2]

Approve a pending rule request. Host-only endpoint. Writes a rule file and triggers reload.

**Request body** (optional overrides):

```json
{
  "rule_id": "allow-pypi",
  "condition": "network.hostname == \"pypi.org\" && http.method == \"GET\"",
  "file_name": "90-agent-approved.yaml"
}
```

If no overrides are provided, the system generates reasonable defaults from the request.

**Success response** (`ApiResponse<RuleRequest>`):

```json
{
  "success": true,
  "data": {
    "id": "req-a1b2c3",
    "submitted_at": "2026-04-21T14:30:00Z",
    "status": "approved",
    "description": "Need access to PyPI for package installation",
    "requested_access": "HTTPS to pypi.org",
    "suggested_condition": "network.hostname == \"pypi.org\" && http.method == \"GET\""
  }
}
```

**Error response** (request not found or not pending):

```json
{
  "success": false,
  "error": "rule request \"req-unknown\" not found"
}
```

### S003-IF-009 POST /api/v1/rule-request/:id/deny [P2]

Deny a pending rule request. Host-only endpoint.

**Request body**: none

**Success response** (`ApiResponse<RuleRequest>`):

```json
{
  "success": true,
  "data": {
    "id": "req-a1b2c3",
    "submitted_at": "2026-04-21T14:30:00Z",
    "status": "denied",
    "description": "Need access to PyPI for package installation",
    "requested_access": "HTTPS to pypi.org",
    "suggested_condition": "network.hostname == \"pypi.org\" && http.method == \"GET\""
  }
}
```

### S003-IF-010 CLI commands [P1]

```
outcall rule list                                                   # list all loaded rules
outcall rule show <id>                                              # show details for a specific rule
outcall rule reload                                                 # trigger rule reload from disk
outcall rule test --expr '<CEL>' --context '<JSON>'                 # test a CEL expression
outcall rule requests                                               # list pending rule requests
outcall rule requests --status approved                             # filter by status
outcall rule approve <request-id>                                   # approve a rule request
outcall rule deny <request-id>                                      # deny a rule request
```

All commands accept the global `--socket <path>` flag.

### S003-IF-011 CLI output format [P1]

**`outcall rule list`**:
```
ID                    FILE             ACTION    CONDITION
allow-github-api      00-base.yaml     allow     $is_github && http.path.startsWith("/api/v3")
block-force-push      00-base.yaml     block     run.tool == "git" && "-f" in run.flags
allow-npm-registry    10-node.yaml     allow     network.hostname == "registry.npmjs.org"
```

**`outcall rule show allow-github-api`**:
```
Rule:        allow-github-api
File:        00-base.yaml
Action:      allow
Log:         false
Description: Allow GitHub API v3 access
Condition:   network.hostname == "github.com" && http.method in ["GET", "POST"] && http.path.startsWith("/api/v3")
```

**`outcall rule reload`** (success):
```
Rules reloaded: 3 files, 12 rules loaded.
Warnings:
  - unused definition "legacy_var" in 50-custom.yaml
```

**`outcall rule reload`** (failure):
```
Error: reload failed: CEL parse error in 50-custom.yaml rule "bad-rule": unexpected token at position 15.
Previous rules remain active.
```

**`outcall rule test --expr '...' --context '...'`**:
```
Result: true
```

**`outcall rule requests`**:
```
ID           SUBMITTED             STATUS    DESCRIPTION
req-a1b2c3   2026-04-21 14:30:00   pending   Need access to PyPI for package installation
req-d4e5f6   2026-04-21 13:00:00   approved  Need access to npm registry
```

**`outcall rule approve req-a1b2c3`**:
```
Rule request "req-a1b2c3" approved. Rule "allow-pypi" added and rules reloaded.
```

**`outcall rule deny req-a1b2c3`**:
```
Rule request "req-a1b2c3" denied.
```

All error output goes to stderr. Exit code 1 on error, 0 on success.

### S003-IF-012 YAML rule file schema [P1]

Complete schema for a rule file:

```yaml
# Required. Only "1" is supported.
version: "1"

# Optional. Reusable CEL sub-expressions.
definitions:
  <name>: <CEL expression>

# Required (may be empty list).
rules:
  - id: <string>                    # Required. Unique across all files.
    condition: <CEL expression>     # Required. Must evaluate to boolean.
    action: <allow|block|enrich>    # Required.
    log: <boolean>                  # Optional. Default: false.
    description: <string>           # Optional. Human-readable.
    priority: <integer>             # Optional. Lower = higher priority.
    egress:                         # Optional. DNS allow follow-up behavior.
      mode: <proxy|direct_ip>      # proxy = no L3/L4 hole; direct_ip = temporary nft allows.
      ports: [<port>, ...]          # Optional. direct_ip only. Default: [80, 443].
    enrich:                         # Required when action is "enrich".
      script: <path>               # Relative to rules directory.
      timeout_ms: <integer>         # Optional. Default: 5000.
```

### S003-IF-013 Context variable types [P1]

CEL type mapping for context variables:

| Variable | CEL Type | Notes |
|----------|----------|-------|
| `network.hostname` | `string` | May be absent (DNS not resolved yet) |
| `network.ip` | `string` | Always present for network requests |
| `network.port` | `int` | |
| `network.protocol` | `string` | `"tcp"` or `"udp"` |
| `http.method` | `string` | Uppercase: `"GET"`, `"POST"`, etc. |
| `http.path` | `string` | Includes leading `/` |
| `http.host` | `string` | From `Host` header |
| `http.headers` | `map(string, string)` | Header names are lowercased |
| `http.body_size` | `int` | Bytes |
| `dns.query` | `string` | Queried domain name |
| `dns.record_type` | `string` | `"A"`, `"AAAA"`, `"CNAME"`, etc. |
| `docker.image` | `string` | Full image reference |
| `docker.command` | `list(string)` | Command and arguments |
| `docker.volumes` | `list(string)` | Volume mount paths |
| `docker.env_keys` | `list(string)` | Environment variable names only (not values) |
| `docker.capabilities` | `list(string)` | Linux capabilities requested |
| `run.tool` | `string` | Tool/binary name |
| `run.args` | `list(string)` | Positional arguments |
| `run.flags` | `list(string)` | Flags including dashes |
| `run.cwd` | `string` | Working directory |
| `run.context` | `map(string, dyn)` | Populated by enrich hooks |
