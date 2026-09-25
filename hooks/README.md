# Hook - apply-guard (optional, dual-target)

A skill *asks* the agent to behave; a **hook is executed by the host, not the model**, so it is a
deterministic, non-bypassable guarantee. This is **optional hardening** - the pack works without
it - with one job, wired for both **Claude Code** and **GitHub Copilot** from a single script.

## What it does

`bin/guard.sh` is a **pre-tool** hook on the shell tool. It **denies** `vela apply`,
`--auto-approve`, and `--yes` unless the human sets `VELA_APPLY_APPROVED=1`. This turns
"stop before apply" from a soft rule into a hard gate. `vela plan` and everything else are
untouched. Deny is host-agnostic: **exit code 2 denies on both hosts**. (Command tracing is
already covered by the host transcript and the Build Report's Run trace, so there is no logging
hook.)

## Wiring (one script, two hosts)

| | Claude Code | GitHub Copilot |
|---|---|---|
| Config | `hooks/hooks.json` (plugin root) | `.github/hooks/vela.json` (**generated** by `scripts/sync-copilot.mjs`) |
| Event | `PreToolUse` | `preToolUse` |
| Command field | `.tool_input.command` | `.toolArgs.command` |
| Invocation | `guard.sh cc` | `guard.sh cp` |

`guard.sh` takes the host as `$1` and normalizes the payload difference internally. **`jq` is
required.**

## Caveats

- **Copilot pre-tool hooks fail *open* on timeout** - a slow guard would let `vela apply`
  through. The guard is trivial and uses a low `timeoutSec`. Claude Code has no such fail-open.
- **VS Code Copilot Chat has no hooks** - only Copilot CLI and the cloud coding agent do. There,
  fall back to custom-agent tool-permission deny-lists / confirmation.

## Enable / disable

- Claude Code: active when the plugin is installed; remove `hooks/hooks.json` to disable.
- Copilot: active when `.github/hooks/vela.json` is present; set `"disableAllHooks": true` or
  remove it to disable.
- To allow an unattended apply for one run, set `VELA_APPLY_APPROVED=1`.
