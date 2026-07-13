# TODOS

Deferred hardening for the multi-agent Sentry fixer (from the 2026-07-12 eng review).

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
