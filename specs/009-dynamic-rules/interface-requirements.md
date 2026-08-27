# S009 Interface Requirements

### S009-IF-001 GET /api/v1/rules/active [P2]

List all currently active dynamic nftables rules.

**Success response** (`ApiResponse<Vec<ActiveRule>>`):

```json
{
  "success": true,
  "data": [
    {
      "container": "my-agent",
      "destination": "github.com",
      "port": 443,
      "protocol": "tcp",
      "nft_handle": 15,
      "inserted_at": "2026-04-22T10:30:00Z",
      "expires_in_secs": 42
    }
  ]
}
```

### S009-IF-002 POST /api/v1/rules/flush [P2]

Remove all dynamic rules, preserving base drop rules.

If an individual delete fails, the daemon restores the base policy and reports
all tracked dynamic rules as removed. If that emergency reset also fails, the
response has `success: false` and the tracked rules remain queryable.

**Success response**:

```json
{ "success": true, "data": { "removed": 5 } }
```

### S009-IF-003 POST /api/v1/rule/allow [P1]

Insert or renew a dynamic allow rule from the trusted host API. This endpoint is
not exposed on the agent socket.

```json
{
  "container": "my-agent",
  "src_ip": "10.200.0.2",
  "destination": "203.0.113.10",
  "protocol": "tcp",
  "port": 443,
  "expires_in_secs": 60
}
```

`expires_in_secs` is optional. Values outside `1..=86400` are rejected. When
omitted, the rule is persistent until another lifecycle cleanup condition
applies. The response returns the inserted or existing `nft_handle`.
