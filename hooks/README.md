# Hook - apply-guard (optional, dual-target)

A skill *asks* the agent to behave; a **hook is executed by the host, not the model**, so it is a
deterministic guardrail. This is **optional hardening** - the pack works without it - with one job,
wired for both **Claude Code** and **GitHub Copilot** from a single script, `bin/guard.sh`.

## What it does

`bin/guard.sh` is a **pre-tool** hook on the shell tool. It **denies** (exit `2`, which denies on
both hosts):

- a `vela apply` command - `vela` as the command word (any path, after env assignments or
  `env`/`command`/`exec`/`sudo`/`time`/`nohup`/`dotnet [tool run]`), in any segment of a compound
  command (`;`, `&&`, `||`, `|`, `&`, newlines, subshells, backticks);
- `--auto-approve` / `--yes` on a `vela` command;
- the same inside `sh -c "..."` / `bash -c` / `eval` (checked conservatively on the raw text).

It **allows** everything else, including:

- `vela plan`, `vela inspect`, `vela apply --help`;
- text that merely *mentions* `vela apply`: quoted strings (`git commit -m "..."`, `grep "vela apply"`)
  and heredoc bodies (`gh pr create --body "$(cat <<'EOF' ... EOF)"`, which the builder uses to post
  the Build Report);
- `--yes` on other tools (`npm i --yes`).

Behaviour is pinned by `test/guard.test.sh` (run in CI).

## Approval

Set `VELA_APPLY_APPROVED=1` **in the environment the host (Claude Code / Copilot CLI) was started
from**, for a run a human has authorized. An inline prefix typed by the agent
(`VELA_APPLY_APPROVED=1 vela apply ...`) does **not** open the gate - the agent cannot approve itself.

## Verified live (2026-10-04)

Claude Code 2.1.287 headless (`claude -p --plugin-dir <this repo>`), vela 0.22.0, the agent asked to run the
command verbatim (a non-existent package, no connection - nothing could reach an org):

| Case | Host env | Result |
| --- | --- | --- |
| `vela apply -p /nonexistent/x.nupkg` | not approved | **denied** by the hook ("Blocked by vela-agentic ... stop-before-apply") |
| `vela plan --help` | not approved | allowed (help printed) |
| `VELA_APPLY_APPROVED=1 vela apply -p ...` (inline) | not approved | **denied** - the agent cannot approve itself |
| `vela apply -p /nonexistent/x.nupkg` | started with `VELA_APPLY_APPROVED=1` | passed the hook; the CLI stopped at "Package not found" (exit 3) |

GitHub Copilot CLI 1.0.91 (`copilot -p ... --allow-all-tools`), same commands:

| Wiring | Result |
| --- | --- |
| plugin (`--plugin-dir`, root `hooks.json`) | `vela apply` **denied** ("Denied by preToolUse hook"); inline approval **denied**; `vela plan --help` allowed; host started with `VELA_APPLY_APPROVED=1` passes the hook (CLI: "Package not found") |
| repo, `.github/hooks/vela.json` | **not loaded** - even a deny-all canary hook there is ignored, trusted folder or not |
| repo, `.github/copilot/settings.json` (`hooks` key) | `vela apply` **denied**, `vela version` allowed - **only in a trusted folder** (untrusted: not loaded) |

So on Copilot, install the **plugin** (robust), or rely on `.github/copilot/settings.json` in a folder you
have trusted. `.github/hooks/vela.json` is kept for hosts that read that location. When testing, keep
paths inside the working directory: Copilot denies an out-of-tree path (`/nonexistent/...`) on its own
unless `--allow-all-paths`, which looks like a hook denial but is not.

## Limits (by design)

- It is a guardrail, not a sandbox. Indirection (`v=vela; $v apply`), a script file that runs `vela
  apply`, or a quoted command word (`"vela" apply`) are not caught. The real barriers stay: the CLI's
  own typed-`yes` confirmation, refusing non-interactive apply without `--auto-approve`, and **not
  giving the agent credentials that can write to the production org**.
- `jq` parses the payload. Without `jq` the guard **fails closed** on any payload mentioning vela and
  apply, and allows the rest.
- POSIX `sh` only (macOS, Linux, WSL). Native Windows shells are not covered.

## Wiring (one script, two hosts)

| | Claude Code | GitHub Copilot |
|---|---|---|
| Config | `hooks/hooks.json` (plugin) | `hooks.json` at the plugin root (Copilot CLI plugin), `.github/copilot/settings.json` (repo hooks the CLI loads, trusted folder) and `.github/hooks/vela.json` - all **generated** by `scripts/sync-copilot.mjs` |
| Event | `PreToolUse`, matcher `Bash` | `preToolUse` (all tools; non-shell payloads are allowed) |
| Command field | `.tool_input.command` | `.toolArgs.command` (object, or a JSON string) |
| Script | `${CLAUDE_PLUGIN_ROOT}/hooks/bin/guard.sh cc` | **embedded**: the config carries `guard.sh` base64-encoded and runs it with `sh -c` |

Why embedded on Copilot: GitHub does not document how a hook's script path is resolved for a plugin
(plugin directory or working directory), and on Copilot a hook that exits non-zero - e.g. "script not
found" - **denies every tool call**. Embedding removes the path question entirely; CI checks the
embedded copy matches `bin/guard.sh`. If it cannot decode (no `base64`), it denies loudly.

Copilot CLI looks for plugin hooks in `hooks.json` **or** `hooks/hooks.json`; which one wins when
both exist is not documented (`hooks/hooks.json` is the Claude Code file). After installing, check
once: ask the agent to run `vela apply -p x.nupkg` and confirm it is blocked.

## Caveats

- **Copilot pre-tool hooks fail *open* on timeout** - a slow guard would let `vela apply` through.
  The guard is fast and uses `timeoutSec: 10`. Claude Code has no such fail-open.
- **VS Code Copilot Chat has no hooks** - only Copilot CLI and the cloud coding agent do. There,
  fall back to custom-agent tool restrictions / confirmation.

## Enable / disable

- Claude Code: active when the plugin is installed; remove `hooks/hooks.json` to disable.
- Copilot: active when the plugin is installed (`hooks.json`) or `.github/hooks/vela.json` is present
  in the repository; set `"disableAllHooks": true` or remove the file to disable.
- Edit only `bin/guard.sh`, then run `node scripts/sync-copilot.mjs` and `sh hooks/test/guard.test.sh`.
