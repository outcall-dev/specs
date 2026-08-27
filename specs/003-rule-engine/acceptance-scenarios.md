# S003 Acceptance Scenarios

### S003-AS-001 Evaluate: allow rule matches [P1]

**Given** the `outcalld` daemon is running and the bridge is up
**And** a rule file contains:
```yaml
version: "1"
rules:
  - id: "allow-github"
    condition: network.hostname == "github.com" && http.method == "GET"
    action: allow
```
**When** an agent container makes an HTTP GET request to `github.com`
**Then** the rule engine returns `decision: allow` with `matched_rule: "allow-github"`
**And** the request is permitted.

### S003-AS-002 Evaluate: block rule matches [P1]

**Given** the `outcalld` daemon is running and the bridge is up
**And** a rule file contains:
```yaml
version: "1"
rules:
  - id: "block-force-push"
    condition: run.tool == "git" && "-f" in run.flags
    action: block
    log: true
```
**When** an authenticated enforcement point evaluates a request with
`run.tool == "git"` and `run.flags` containing `-f`
**Then** the rule engine returns `decision: block` with `matched_rule: "block-force-push"`
**And** a structured log entry is emitted with the rule ID, source file, and decision
**And** the request is denied.

### S003-AS-003 Evaluate: no rule matches (default block) [P1]

**Given** the `outcalld` daemon is running and the bridge is up
**And** no rule condition matches the incoming request
**When** an agent container makes an HTTP request to `evil.example.com`
**Then** the rule engine returns `decision: block` with `matched_rule: null`
**And** the request is denied.

### S003-AS-004 Evaluate: first match wins ordering [P1]

**Given** the `outcalld` daemon is running and the bridge is up
**And** file `00-base.yaml` contains:
```yaml
version: "1"
rules:
  - id: "allow-all-github"
    condition: network.hostname == "github.com"
    action: allow
```
**And** file `10-restrictions.yaml` contains:
```yaml
version: "1"
rules:
  - id: "block-github-admin"
    condition: network.hostname == "github.com" && http.path.startsWith("/admin")
    action: block
```
**When** an agent makes a request to `github.com/admin/settings`
**Then** the rule engine returns `decision: allow` with `matched_rule: "allow-all-github"`
**Because** `00-base.yaml` sorts before `10-restrictions.yaml` and the first match wins.

### S003-AS-005 Evaluate: definition variable expansion [P2]

**Given** the `outcalld` daemon is running and the bridge is up
**And** a rule file contains:
```yaml
version: "1"
definitions:
  is_github: network.hostname == "github.com"
rules:
  - id: "allow-github-api"
    condition: $is_github && http.path.startsWith("/api/v3")
    action: allow
```
**When** an agent makes a GET request to `github.com/api/v3/repos`
**Then** the rule engine expands `$is_github` to `(network.hostname == "github.com")`
**And** evaluates the full condition
**And** returns `decision: allow`.

### S003-AS-006 Startup: unsafe enrich action is rejected [P1]

**Given** a rule file contains:
```yaml
version: "1"
rules:
  - id: "enrich-git-context"
    condition: run.tool == "git"
    action: enrich
    enrich:
      script: hooks/check-repo.sh
```
**When** `outcalld` starts or reloads rules
**Then** static analysis rejects the rule set
**And** the script is not executed
**And** an existing active rule set remains active during reload.

### S003-AS-007 Startup: CEL parse error aborts [P1]

**Given** a rule file contains an invalid CEL expression:
```yaml
version: "1"
rules:
  - id: "bad-rule"
    condition: "network.hostname =="
    action: allow
```
**When** `outcalld` starts
**Then** static analysis detects the CEL parse error
**And** the daemon logs the error with the file name, rule ID, and parse details
**And** the daemon aborts startup with a non-zero exit code.

### S003-AS-008 Startup: unused definition warns [P1]

**Given** a rule file contains:
```yaml
version: "1"
definitions:
  unused_var: network.hostname == "example.com"
rules:
  - id: "allow-all"
    condition: "true"
    action: allow
```
**When** `outcalld` starts
**Then** static analysis detects that `unused_var` is never referenced
**And** the daemon logs a warning
**And** the daemon starts successfully.

### S003-AS-009 Hot reload: via API [P2]

**Given** the `outcalld` daemon is running with rules loaded
**And** the host operator has modified a rule file on disk
**When** the host operator calls `POST /api/v1/rules/reload`
**Then** `outcalld` re-reads the rules directory
**And** validates the new rule set
**And** atomically swaps the new rules into the active set
**And** returns the count of files and rules loaded.

### S003-AS-010 Hot reload: via file watch [P2]

**Given** the `outcalld` daemon is running with file watch enabled
**When** a rule file is modified, added, or removed in the rules directory
**Then** `outcalld` detects the change
**And** performs the same validation and atomic swap as API-triggered reload
**And** logs the reload result.

### S003-AS-011 Evaluate: multi-file filename sort order [P1]

**Given** the rules directory contains files with equal/default priority:
`50-custom.yaml`, `00-base.yaml`, `25-team.yaml`
**When** `outcalld` loads rules
**Then** files are loaded in order: `00-base.yaml`, `25-team.yaml`, `50-custom.yaml`
**And** rules from `00-base.yaml` are evaluated before rules from `25-team.yaml`
**And** rules from `25-team.yaml` are evaluated before rules from `50-custom.yaml`.

### S003-AS-012 Agent: submits rule request [P3]

**Given** the `outcalld` daemon is running
**When** an authenticated managed agent submits `POST /v1/requests/rules` on
the agent socket with:
```json
{
  "rule_file": "version: \"1\"\nrules:\n  - id: allow-pypi\n    condition: 'network.hostname == \"pypi.org\"'\n    action: allow\n"
}
```
**Then** the rule file is validated and durably queued with status `pending`
**And** the agent receives a request ID
**And** the request does not affect rule evaluation.

### S003-AS-013 Host: approves rule request [P2]

**Given** a pending rule request exists with ID `req-001`
**When** the host operator calls `POST /api/v1/requests/rules/req-001/approve`
**Then** `outcalld` atomically writes a mode-0600 rule file to the rules directory
**And** triggers an automatic reload
**And** the new rule is active for subsequent evaluations.

### S003-AS-014 Host: rejects rule request [P2]

**Given** a pending rule request exists with ID `req-001`
**When** the host operator calls `POST /api/v1/requests/rules/req-001/reject`
**Then** the request status changes to `rejected`
**And** no rule file is written
**And** active rules are unchanged.

### S003-AS-015 CLI: lists loaded rules [P1]

**Given** the `outcalld` daemon is running with rules loaded
**When** the user runs `outcall rules list`
**Then** the CLI prints a table of all loaded rules with their IDs, files, actions, and condition previews
**And** the command exits with code 0.

### S003-AS-016 CLI: tests expression against mock context [P2]

**Given** the `outcalld` daemon is running
**When** the user runs:
```
outcall rules test --expr 'network.hostname == "github.com"' --context '{"network":{"hostname":"github.com","ip":"1.2.3.4","port":443,"protocol":"tcp"}}'
```
**Then** the CLI prints `Result: true`
**And** the command exits with code 0.

### S003-AS-017 Evaluate: log flag produces audit entry [P1]

**Given** a rule with `log: true` matches a request
**When** the evaluation completes
**Then** `outcalld` emits a structured log entry at info level containing:
  - rule ID
  - decision (allow or block)
  - timestamp
  - source rule file
**And** request headers, bodies, and environment values are not logged.

### S003-AS-018 CLI: daemon not running [P1]

**Given** the `outcalld` daemon is not running
**When** the user runs a daemon-backed `outcall rules` or `outcall requests` command
**Then** the CLI prints `Error: cannot connect to outcalld at <socket> -- is it running?`
**And** the command exits with code 1.
