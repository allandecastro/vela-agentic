# Hooks — deterministic enforcement (optional, dual-target)

Skills *ask* the agent to behave; a **hook is executed by the host, not the model**, so it is a
deterministic, non-bypassable guarantee. This layer is **optional hardening** — the pack works
without it — and it targets both **Claude Code** and **GitHub Copilot** from one shared script.

## What it does

- **Apply-guard (`bin/guard.sh`)** — a **pre-tool** hook on the shell tool. It **denies**
  `vela apply`, `--auto-approve`, and `--yes` unless the human sets `VELA_APPLY_APPROVED=1`. This
  turns "stop before apply" from a soft rule into a hard gate. `vela plan` and everything else are
  untouched. Deny is host-agnostic: **exit code 2 denies on both hosts**.
- **Run-trace logger (`bin/trace.sh`)** — a **post-tool** hook that appends every `vela` / `dotnet`
  / `mono` command to `./.vela/run-trace.log` (or `~/.vela`), so a run is auditable even if the
  Build Report's Run trace was not filled. Post-hooks cannot block; this is observability only.

## Wiring (one logic, two hosts)

| | Claude Code | GitHub Copilot |
|---|---|---|
| Config | `hooks/hooks.json` (this repo, plugin root) | `.github/hooks/vela.json` (**generated** by `scripts/sync-copilot.mjs`) |
| Events | `PreToolUse` / `PostToolUse` | `preToolUse` / `postToolUse` |
| Command field | `.tool_input.command` | `.toolArgs.command` |
| Script | `guard.sh cc` / `trace.sh cc` | `guard.sh cp` / `trace.sh cp` |

The scripts read the host as `$1` and normalize the payload difference internally. **`jq` is
required.**

## Caveats (be honest)

- **Copilot pre-tool hooks fail *open* on timeout** — a slow guard would let `vela apply` through.
  We keep the guard trivial and set a low `timeoutSec`. Claude Code does not carry this fail-open.
- **VS Code Copilot Chat has no hooks** — only Copilot CLI and the cloud coding agent do. In
  VS Code + Copilot, fall back to custom-agent tool permission deny-lists / confirmation.
- Post-tool hooks receive the shell exit code embedded in the result text, not as a clean field —
  the trace logs the command + timestamp; the Build Report's Run trace carries verdicts/exit codes.

## Enable / disable

- Claude Code: active when the plugin is installed. Remove `hooks/hooks.json` to disable.
- Copilot: active when `.github/hooks/vela.json` is present. Set `"disableAllHooks": true` or
  remove the file to disable.
- To allow an unattended apply for one run, set `VELA_APPLY_APPROVED=1` in the environment.
