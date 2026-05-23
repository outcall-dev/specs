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
      "inserted_at": "2026-04-22T10:30:00Z"
    }
  ]
}
```

### S009-IF-002 POST /api/v1/rules/flush [P2]

Remove all dynamic rules, preserving base drop rules.

**Success response**:

```json
{ "success": true, "data": { "removed": 5 } }
```
