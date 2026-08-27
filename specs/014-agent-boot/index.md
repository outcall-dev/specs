# S014: Managed Recipe Runtime

| Field | Value |
|-------|-------|
| Spec | S014 |
| Feature | Managed Recipe Runtime |
| Date | 2026-05-14 |
| Updated | 2026-08-27 |
| Status | Implemented |
| Author | @marktopper |

## Overview

`outcall run <recipe>` initializes and launches an AI agent in a hardened,
daemon-managed Linux container from the current project. Built-in `claude` and
`codex` recipes define their images, provider authentication candidates,
project context, and initial egress rules.

The current project is mounted read-write at `/workspace`. Its `.outcall`
subdirectory is over-mounted read-only so an agent can change project code but
cannot rewrite the registry or policy controlling its host and network access.

## User Story

As a developer, I want one command to launch Claude or Codex in an isolated
project container, with predictable authentication and deny-by-default host and
network access, so I can leave the agent running without granting host control.

## Acceptance Scenarios

### AS-001: First Run

**Given** the current folder is `~/projects/foobar` and has no `.outcall`
configuration

**When** the operator runs `outcall run codex`

**Then** Outcall initializes the Codex recipe, builds its local image, starts or
reconciles the daemon with the project rules, verifies bridge netfilter, creates
the managed network, and launches container `foobar-1` through `outcalld`.

### AS-002: One-Shot Agent Command

**When** the operator runs one of:

```bash
outcall run codex -- exec "Say hi"
outcall run claude -- -p "Say hi"
```

**Then** arguments are passed directly to the recipe entrypoint without shell
evaluation, Outcall waits for the container, and a non-zero agent exit status
causes the command to fail.

### AS-003: Project Configuration

**Given** `.outcall/agent.yaml` specifies a custom image, environment, resource
limits, volume, or container workspace

**When** the operator runs the recipe

**Then** supported settings are applied, CLI `--name` and `--detach` take
precedence, unknown keys fail parsing, and unsafe port or capability requests
are rejected before Docker is called.

### AS-004: Parallel Agents

**Given** `foobar-1` is present

**When** the recipe is launched again

**Then** Outcall selects the first available numeric name (`foobar-2`, then
`foobar-3`, and so on), retries concurrent name claims, and allows an explicit
override with `--name`.

### AS-005: Lifecycle

**Given** a detached managed agent is running

**When** the operator runs `outcall ps`, `outcall inspect <name>`,
`outcall logs <name>`, `outcall attach <name>`, or `outcall stop <name>`

**Then** the CLI lists, inspects with environment values redacted, streams logs,
attaches to the inspected immutable ID, or stops and removes the daemon-managed
container. `outcall stop <name> --keep` MUST retain the stopped container for
postmortem logs or inspection, while low-level `container stop` remains
stop-only.

### AS-006: Fail-Closed Network

**Given** bridge netfilter is unavailable, the selected network is not backed by
the configured Outcall bridge, or the daemon cannot load the project rules

**When** the operator launches a recipe

**Then** launch is refused; the CLI does not fall back to raw `docker run`, the
default Docker bridge, or an empty policy directory.

## Functional Requirements

### FR-001: Command Interface

The supported launch interface is:

```text
outcall run <claude|codex> [--force] [--no-build]
            [--auth <auto|copy|mount|env-only>] [--force-auth-copy]
            [--include-global-config]
            [--detach] [--keep] [--name <name>] [-- <agent arguments>...]
```

Legacy `outcall agent`, `outcall start`, `outcall codex`, `outcall claude`, and
`outcall recipe run` aliases MUST NOT be exposed.

### FR-002: Initialization and Images

The first run MUST create the recipe Dockerfile, manifest, context guide,
project rule file, `.outcall/agent.yaml`, host-resource registry, and runtime
gitignore entries without replacing operator-owned shared configuration.
Repeated setup MUST preserve every existing real file and restore any missing
generated file; a partial scaffold MUST NOT be treated as complete.

The generated local image MUST be built from only the recipe directory as its
Docker build context. `--no-build` MUST require that the local image already
exists. A missing custom image MAY be pulled only when `auto_pull: true`.

### FR-003: Naming

The effective name MUST use this order:

1. CLI `--name`
2. `.outcall/agent.yaml` `name`
3. Sanitized current folder name plus the first available positive integer

Automatic name conflicts caused by concurrent launches MUST be retried with a
higher suffix through daemon create responses, without querying all host Docker
containers directly. Explicit names MUST fail on conflict rather than silently
change.

Successful attached and one-shot runs MUST remove their stopped container by
default, allowing the first available suffix to be reused. `--keep` MUST retain
a completed container for inspection. Detached containers MUST remain running
until explicitly stopped. Top-level `outcall stop` MUST remove the stopped
container by default and MUST retain it when passed `--keep`.

### FR-004: Configuration

`.outcall/agent.yaml` supports:

```yaml
image: custom-agent:latest
name: foobar-review
workspace: /workspace
network: outcall-default
detach: false
auto_pull: true
volumes:
  - /absolute/host/path:/container/path:ro
env:
  KEY: value
resources:
  memory: 4g
  cpus: "1024" # Docker CPU shares, not a CPU-count limit
entrypoint: ["codex"]
command: ["exec", "Review this project"]
```

Unknown fields MUST fail. `workspace` MUST be a clean absolute container path
other than `/`. The network MUST use an `outcall-` name and pass daemon-side
bridge identity validation. Memory MUST be at least 6 MiB and CPU shares MUST
be at least 2.

Published ports and added Linux capabilities MUST be rejected in secure managed
mode. User-declared volumes MUST pass daemon-side protected-path and symlink
validation before container creation.

### FR-005: Authentication and Context

Auth mode `auto` MUST prefer a saved project choice, then provider environment
credentials, then selected provider copy paths, then an isolated project home.
Configuration paths MUST NOT count as authentication unless a non-empty
provider environment credential or a declared portable credential file exists.

Every mode MUST reuse owner-only `.outcall/home/<recipe>/` runtime state. Copy
mode MUST copy only portable credential paths by default. The
`--include-global-config` option MAY add only the recipe's explicit global-config
allowlist in auto, copy, and env-only modes; mount mode already includes the
complete provider directory. Selected-file staging MUST NOT follow symlinks and
MUST reject files larger than 16 MiB, more than 10,000 entries, or more than 100
MiB total. Existing legacy `.outcall/auth/<recipe>/home` state MUST migrate
without losing provider credentials or container sessions. The project-local
home SHOULD be mounted at the validated recipe home (`/home/node` by default)
inside a Unix container. The runtime MUST NOT claim to rewrite host-absolute MCP
or hook executable paths for Linux portability.

Mount mode MUST be an explicit read-write opt-in for only the recipe's complete
provider paths, never the complete host home, and MUST disclose that changes
persist on the host. Secret runtime directories and credential files MUST use
owner-only permissions on Unix.

macOS Keychain login state MUST NOT be treated as a portable Linux credential.
An attached argument-free run MUST allow provider login and persist the Linux
credential in the project home. Batch or detached runs that need inference MUST
fail before image build when no portable credential exists. Metadata/help and
provider-login commands MAY run without credentials. Claude guidance MUST name
interactive `/login`, `CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token`, and
the supported Anthropic API environment credentials.

The project itself is the default context transfer mechanism. Recipe-specific files
such as `AGENTS.md`, `CLAUDE.md`, `.codex/config.toml`, and
`.claude/settings.json` remain available through the project mount when present.

### FR-006: Managed Container Boundary

Recipe containers MUST be created through `POST /api/v1/container/create` on
the daemon host socket. The daemon MUST attach only to a Docker bridge backed by
its configured Outcall bridge, force its DNS and proxy environment, use a
read-only root filesystem, drop all Linux capabilities, set
`no-new-privileges`, run as the invoking user's numeric non-root UID/GID, and
apply memory, CPU-share, and PID limits. The daemon MUST reject root identities
and use a non-root fallback when an older client omits the identity.

Recipe containers MUST NOT receive the Docker socket, host API socket, or
daemon helper mounts. The current project MUST be mounted read-write and its
`.outcall` directory MUST be over-mounted read-only.

The CLI MUST send the complete managed-container request and MUST reject an
incompatible daemon response instead of retrying without entrypoint, working
directory, helper-mount, interactive, or TTY fields. A running official daemon
image from an older Outcall release MUST be reconciled to the CLI-matched image
before launch. An existing custom daemon image MAY be preserved; operators can
select one explicitly with `OUTCALL_DAEMON_IMAGE`.

The built-in Codex recipe MUST treat this hardened container as the outer
sandbox and invoke Codex with `--sandbox danger-full-access`. Managed agents do
not receive the namespace/capability access required for a reliable nested
`bubblewrap` sandbox; Docker mounts, read-only root, dropped capabilities, and
Outcall egress enforcement remain authoritative.

### FR-007: Rules and Host Resources

The project rule directory MUST be mounted into the daemon and reloaded before
launch. Network access defaults to deny unless a recipe or operator rule allows
it. The built-in Claude provider grant MUST include `api.anthropic.com`,
`claude.ai`, and `platform.claude.com` so model requests and interactive login
can traverse the managed proxy without broad Anthropic-domain access.

Host files outside explicit Docker mounts and host-native tools MUST be declared
in `.outcall/host-resources.yaml`, granted with
`outcall allow <recipe> <tool:id|file:id>`, and accessed through the tokenized
host broker. Declaration alone MUST NOT grant access.

The v1 host tool interface MUST remain a bounded, one-shot request/response API.
Documentation MUST NOT claim transparent forwarding for long-lived stdio, SSE,
or Streamable HTTP MCP sessions. MCP servers SHOULD run inside the Linux recipe
image where network policy applies; a host-native server MAY be exposed through
a narrow wrapper that completes one operation per broker request.

### FR-008: Attached and Detached Execution

Attached interactive runs MAY allocate a TTY and attach with Docker. An
argument-free detached interactive run MUST set Docker `OpenStdin` and `Tty` so
Claude/Codex remain attachable without a host terminal. One-shot argument or
configured-command runs MUST remain non-interactive, wait, and propagate the
container exit status. Detached runs MUST print only Outcall lifecycle commands,
including `outcall attach <name>`. A normal Docker detach sequence MUST return
success, report that the agent remains running, and MUST NOT trigger completed-
container cleanup.

## Edge Cases

| Case | Required behavior |
|------|-------------------|
| Docker unavailable | Retry briefly, then print platform-specific recovery guidance |
| Recipe image stale | Rebuild only when recipe-directory fingerprint changes |
| Partial generated scaffold | Restore missing files without replacing existing custom content |
| `--no-build` image missing | Fail with instruction to rerun without `--no-build` |
| Custom image missing, `auto_pull: false` | Fail without an implicit pull |
| Unknown YAML field | Fail with the config path and parse error |
| Ports or capabilities configured | Reject before launch |
| Non-Outcall or forged Docker network | Reject after Docker network inspection |
| Protected or symlinked control-socket mount | Reject before Docker create |
| Existing daemon uses other rules | Restart it with this project's canonical rules directory |
| Existing daemon uses an older official image | Restart it with the official image matching the installed CLI |
| Existing daemon uses a custom image | Preserve that image on a rules-mount restart unless `OUTCALL_DAEMON_IMAGE` explicitly selects another image |
| Daemon rejects current container fields | Fail with the daemon error; never retry with a weaker legacy request |
| macOS Claude config exists but no portable credential | Allow attached interactive `/login`; reject inference batch/detached runs before build with exact recovery commands |
| Host config includes symlinks or oversized trees | Skip symlinks and reject copy above fixed file, entry, or total-size limits before copying |
| Global config contains host-only MCP or hook executables | Do not copy it by default; require `--include-global-config` and print review guidance |
| Legacy staged provider home exists | Migrate it to `.outcall/home/<recipe>` without dropping credentials or sessions |
| Agent exits non-zero | Return failure and retain useful logs |

## Success Criteria

- [x] `outcall run claude` and `outcall run codex` use daemon-managed containers.
- [x] A clean project is initialized on first run.
- [x] Names default to `<folder>-1`, `<folder>-2`, and so on.
- [x] Successful attached runs clean up their container and reuse free suffixes unless `--keep` is set.
- [x] `.outcall/agent.yaml` is parsed, merged, validated, and applied.
- [x] Authentication can be copied, mounted, or supplied by environment.
- [x] Provider configuration cannot masquerade as unattended authentication.
- [x] Claude interactive login and project-local credential persistence are supported without copying macOS Keychain state.
- [x] Default auth/config copies are selective, bounded, symlink-safe, and owner-only.
- [x] Project code is read-write while `.outcall` policy is read-only.
- [x] Egress is attached only to the enforced Outcall bridge.
- [x] Host tools/files are deny-by-default and broker-mediated when declared.
- [x] Lifecycle commands work for parallel detached agents.
