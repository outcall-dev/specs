# S014: Agent Boot Command

| Field | Value |
|-------|-------|
| Spec | S014 |
| Feature | Agent Boot Command |
| Date | 2026-05-14 |
| Status | Implemented |
| Author | @marktopper |

## Overview

The `outcall agent` command boots an isolated AI agent container from any
project folder. The agent has the codebase mounted at `/workspace`, runs behind
Outcall's traffic controls, and can be customized per-project via
`.outcall/agent.yaml`.

## User Story

As a developer, I want to boot an isolated AI agent container from any project folder with a single command (`outcall agent`), so the agent has my codebase, tools, and runs behind Outcall's traffic controls.

## Acceptance Scenarios

### AS-001: Basic Agent Boot
**Given** I'm in a project folder at `~/my-project`
**When** I run `outcall agent`
**Then** an agent container named `my-project-agent` boots on the outcall bridge
**And** the current directory is mounted at `/workspace` inside the container
**And** Claude Code is pre-installed and ready

### AS-002: Custom Entrypoint Arguments
**Given** an agent container is running
**When** I run `outcall agent "analyze this codebase for security issues"`
**Then** the container receives the argument string as its entrypoint command
**And** Claude Code executes the prompt immediately

### AS-003: Project-Specific Configuration
**Given** a `.outcall/agent.yaml` exists in the project folder
**When** I run `outcall agent`
**Then** the agent boots using the custom image specified in the config
**And** the custom environment variables are set
**And** the custom volume mounts are applied

### AS-004: Multiple Agents Per Project
**Given** a project already has a running agent
**When** I run `outcall agent --name my-agent-2`
**Then** a second agent container boots with the specified name
**And** both agents share the outcall bridge and traffic rules

### AS-005: Agent Cleanup
**Given** an agent container is running
**When** I press Ctrl+C or run `outcall agent --stop`
**Then** the container stops gracefully
**And** its network namespace is cleaned up

## Functional Requirements

### FR-001: Command Interface
The CLI SHALL support:
```bash
outcall agent                          # Boot default agent
outcall agent "<command>"              # Boot with entrypoint args
outcall agent --name <name>            # Custom name
outcall agent --image <image>          # Custom image
outcall agent --stop [name]            # Stop agent
outcall agent --list                   # List running agents
outcall agent --logs [name]            # Show agent logs
```

### FR-002: Auto-Naming
The agent name SHALL be derived from:
1. `--name` flag if provided
2. `name` field from `.outcall/agent.yaml` if present
3. Current directory name + `-agent` suffix (e.g., `my-project-agent`)

### FR-003: Default Agent Image
The default agent image SHALL include:
- Ubuntu 24.04 or Debian Bookworm base
- Claude Code CLI (latest)
- Git, curl, basic build tools
- Non-root user `agent` with sudo
- Pre-configured to use `/workspace` as working directory

### FR-004: Configuration File
The `.outcall/agent.yaml` SHALL support:
```yaml
image: custom-image:latest          # Custom Docker image
name: my-custom-agent               # Override default name
volumes:
  - /host/path:/container/path      # Additional mounts
env:
  KEY: value                        # Environment variables
ports:
  - 3000:3000                      # Port forwarding
capabilities:
  - NET_ADMIN                       # Additional capabilities
resources:
  memory: 4g                        # Memory limit
  cpus: 2                           # CPU limit
entrypoint: ["/bin/bash", "-c"]    # Custom entrypoint
```

### FR-005: Entrypoint Passthrough
When arguments are passed to `outcall agent`:
- If config specifies `entrypoint`, use that + args
- Otherwise, default to: `claude "<args>"`
- Arguments SHALL be properly shell-escaped

### FR-006: Network Integration
The agent SHALL:
- Connect to the existing outcall bridge (`outcall0` by default)
- Use an IP from the bridge subnet (auto-allocated)
- Be subject to all outcall traffic rules
- Register itself with the outcalld agent registry

### FR-007: Code Mounting
The current working directory SHALL be mounted at `/workspace` inside the container with read-write permissions.

### FR-008: State Management
Running agents SHALL be tracked in:
- Docker container labels (`outcall.agent=true`, `outcall.project=<folder>`)
- Agent registry in outcalld
- Local state file: `.outcall/state.json`

## Interface Requirements

### CLI Commands

```
outcall agent [OPTIONS] [ARGS...]

Options:
  -n, --name <NAME>          Agent name (default: <folder>-agent)
  -i, --image <IMAGE>        Docker image (default: outcall/agent:latest)
  -w, --workspace <PATH>     Mount path (default: .)
  --stop [NAME]              Stop agent (default: auto-detected)
  --list                     List running agents
  --logs [NAME]              Show agent logs
  --restart                  Restart if already running
  --detach                   Run in background
  -h, --help                 Print help

Args:
  Command to pass to agent entrypoint
```

## Edge Cases

| Case | Behavior |
|------|----------|
| Bridge not running | Auto-start bridge with warning |
| Name collision | Error with suggestion to use `--name` |
| Image not found | Pull image automatically or error |
| No .outcall directory | Use defaults, create on first run |
| Port conflict | Auto-increment port numbers |
| Low disk space | Warning but continue |
| Agent exits immediately | Show logs and exit code |

## Implementation Plan

### Phase 1: Basic Agent Boot
- Create default agent Dockerfile
- Implement `outcall agent` command
- Handle basic container lifecycle

### Phase 2: Configuration
- Implement `.outcall/agent.yaml` parser
- Add config merging logic
- Support custom images and volumes

### Phase 3: Entrypoint Passthrough
- Implement argument forwarding
- Add shell escaping
- Support custom entrypoints

### Phase 4: Integration
- Register agents with outcalld
- Add state management
- Implement list/stop/logs commands

## Success Criteria

- [ ] `outcall agent` boots a working agent in < 10 seconds
- [ ] `outcall agent "hello"` passes argument to container
- [ ] `.outcall/agent.yaml` customizes agent behavior
- [ ] Multiple agents can run simultaneously
- [ ] Agent traffic is filtered by outcall rules
- [ ] Codebase is accessible at `/workspace`
