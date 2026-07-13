# machine0-ubuntu

This repository contains the Ansible playbooks used to build the [machine0](https://machine0.io) Ubuntu system images. This is a great place to start if you want to customize your Ubuntu VM.

### Usage
```bash
# install the machine0 CLI
curl -LsSf https://machine0.io/install.sh | sh

# create an Ubuntu VM
machine0 new ubuntu --image ubuntu-24-04-loaded --size small

# clone the repo, customize and rebuild
git clone https://github.com/fdmtl/machine0-ubuntu.git && cd machine0-ubuntu
claude -p "make any change to the loaded playbook you'd like"
machine0 provision ubuntu loaded.yml

# or, provision from within the VM
machine0 ssh ubuntu
git clone https://github.com/fdmtl/machine0-ubuntu.git && cd machine0-ubuntu
ansible-playbook -i "localhost," -c local loaded.yml
```

### Playbooks

| Image Name | Playbook | Description |
|---|---|---|
| `ubuntu-24-04-loaded` | `loaded.yml` | Modern agents (Claude Code, OpenAI Codex) and dev tools (e.g. Docker, Node, Python, GitHub CLI, machine0 CLI...). |
| `ubuntu-24-04-openclaw` | `openclaw.yml` | Loaded + [OpenClaw](https://github.com/openclawai/OpenClaw). |
| `ubuntu-24-04-hermes` | `hermes.yml` | Loaded + [Hermes](https://hermes-agent.nousresearch.com). |
| `m0-controller` | `m0-controller.yml` | Loaded variant branded for the multi-agent Sentry fixer controller. |
| `m0-worker` | `m0-worker.yml` | Loaded variant branded for the multi-agent Sentry fixer workers. |

## Multi-agent Sentry fixer (m0-controller / m0-worker)

A controller VM (Claude Code) pulls the top 3 recurring Sentry issues and fans out one disposable worker VM (Codex) per issue. Each worker clones [fdmtl/machine0](https://github.com/fdmtl/machine0), branches, applies a fix, and opens a PR (or writes a no-fix diagnosis). The controller collects results, pulls forensics, and deletes the workers.

### Prerequisites

Server-side state this repo cannot create for you:

- Profiles `m0-controller` and `m0-worker` exist, with these integrations connected: `claude-code`, `codex`, `github`, `sentry` (MCP, `https://mcp.sentry.dev/mcp`) — plus `machine0-cli` on the **controller** profile (workers don't need it). `./setup-profiles.sh` runs `machine0 integrations check` and fails fast if something is broken.
- The GitHub App installation (the `github` integration) has **write** access to `fdmtl/machine0`.
- A positive account balance — the controller creates up to 3 VMs per run.

### Setup

```bash
# 1. Build both images in parallel ("" suffix → stable names m0-controller / m0-worker;
#    rebuilding an existing image creates a draft version and auto-promotes it)
./make-image.sh m0-worker.yml small "" & ./make-image.sh m0-controller.yml small "" & wait

# 2. Register the prompts and set DEV_MODE=true (use --prod for the real thing)
./setup-profiles.sh
```

The controller prompt is composed at registration: `prompts/process-sentry.md` embeds `prompts/fix-sentry-issue.md` at the `{{WORKER_SOP}}` marker, so the worker SOP has a single source of truth.

### Run

```bash
machine0 new controller --image m0-controller --profile m0-controller --size medium
machine0 ssh controller
claude
# then invoke: /mcp__machine0__process-sentry
```

### DEV_MODE

`DEV_MODE` is a profile var on `m0-controller`, injected into the VM at **creation** time — flipping it (`./setup-profiles.sh --prod`) requires recreating the controller VM.

- `DEV_MODE=true` (default): workers are created and dispatched a trivial detached `codex exec` round-trip (proves VM startup, file shipping, detached execution, and result collection) — no cloning, no pushes, no PRs.
- `DEV_MODE=false`: the full flow — workers fix real issues and open PRs on `fdmtl/machine0`.

Notes: `/mcp__machine0__fix-sentry-issue` on the worker profile is a manual-use template (its placeholders are filled by the controller at dispatch time; MCP prompts take no arguments yet). Run forensics land on the controller under `~/runs/<runid>/`.
