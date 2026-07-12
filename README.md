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
