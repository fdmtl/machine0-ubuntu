# TODOS

Deferred hardening for the multi-agent Sentry fixer (from the 2026-07-12 eng review
and the 2026-07-13 pre-landing adversarial review).

## [P1 before prod use] Contain the Sentry → autonomous-agent trust boundary

- **What:** The prod flow feeds attacker-controllable Sentry text (title/culprit/stacktrace — anyone who can trigger an error in the product controls it) into `codex exec --dangerously-bypass-approvals-and-sandbox` on a worker holding a GitHub App token with **write** on `fdmtl/machine0`. v1 mitigations landed in the prompts (untrusted-DATA fencing in both prompts; shortid-only in shell command templates; PR body via `--body-file`), but prompt-level fences are not a hard boundary.
- **Why:** A crafted exception message can attempt prompt injection → poisoned "fix" PR (supply-chain) or token/`~/.codex/auth.json` exfiltration via the worker's unrestricted egress.
- **Do before running prod (`DEV_MODE=false`) against a real project:**
  - Scope the worker's GitHub credential to **push-only on `fix/*` branches** of the one repo; require branch protection on `main`.
  - Add egress allowlisting to `m0-worker.yml` (`06-firewall` currently `default allow outgoing`): permit only github.com, the Sentry API, and the model endpoint.
  - Keep the human PR review as the trust gate (see PR quality gating below); never auto-merge.
- **Context:** All three adversarial passes (Red Team, Claude, Codex) named this the dominant risk. `DEV_MODE=true` (the hard default, which substitutes none of this text) is the reason v1 is safe to ship.

## Machine-enforced DEV_MODE / VM-lifecycle guardrails

- **What:** Today `DEV_MODE` and the "only rm `m0-worker-$runid-*`" / "max 3 workers" limits are advisory prompt text the controller LLM interprets — the same LLM that untrusted Sentry text can influence. Move them behind mechanism: Claude Code deny-rules on the controller image (block `machine0 rm` targets not matching `m0-worker-$runid-*`, block `machine0 rm --all`), and a real orphan reaper (VM-creation TTL if machine0 supports one, or a cron/systemd janitor baked into `m0-controller.yml` that removes `m0-worker-*` older than N hours).
- **Why:** Controller death between fan-out and cleanup leaks billing VMs with repo-write creds; Phase 5 currently only *reports* orphans with a reclaim command. A prompt-injected controller could also ignore the soft limits.
- **Context:** Orphaned-VM + advisory-gate findings from the adversarial review. Pairs naturally with the script-based orchestration item below (a real scheduler owns lifecycle deterministically).

## Script-based orchestration for the controller

- **What:** Replace the LLM-driven fan-out loop in `prompts/process-sentry.md` with a shell/Python helper script baked into the `m0-controller` image; Claude invokes the script instead of being the scheduler.
- **Why:** VM creation, polling, timeouts, and cleanup are deterministic work; a script makes them reproducible and cheaper. The v1 keeps the LLM as orchestrator deliberately — agent-driven orchestration is the demo.
- **Pros:** Deterministic retries/timeouts, testable, fewer tokens. **Cons:** Loses the demo value; script needs distribution into the image (rebuild cycle).
- **Context:** Raised by the Codex outside-voice review. Start from the Phase 2–4 commands in `prompts/process-sentry.md`.
- **Depends on:** v1 flow proven end-to-end in prod mode.

## CI pipeline for image builds

- **What:** GitHub Actions workflow that runs the static gates (ansible syntax-check, shellcheck) on PRs, and optionally rebuilds/promotes `m0-*` images on merge via `make-image.sh`.
- **Why:** Builds are manual today; images drift from the playbooks silently.
- **Pros:** Reproducible images, drift detection. **Cons:** Needs a machine0 API key as a repo secret; image builds cost VM time per run.
- **Context:** Flagged by the eng review distribution check. `make-image.sh` already supports stable names + draft promotion, so CI only needs to call it.
- **Depends on:** deciding where the machine0 API key lives.

## PR quality gating in the controller

- **What:** Before reporting a worker PR as success, have the controller check CI status (`gh pr checks`) and inspect the diff size/scope against the reported `files_changed`.
- **Why:** "PR opened" is treated as success in v1; a worker can open a low-quality or unrelated PR and the run still reports PASS.
- **Pros:** Catches noise before humans review. **Cons:** Longer runs (waiting on CI); needs judgment rules for "acceptable" diffs.
- **Context:** Raised by the Codex outside-voice review. The `result.txt` contract (root_cause, files_changed, tests_run) already provides the inputs.
- **Depends on:** fdmtl/machine0 having CI checks that run on PRs.
