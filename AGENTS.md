# Vela agent guide

Durable rules for any AI agent (Claude Code, GitHub Copilot, or other) that drives
**Vela** through its command-line interface. This is the shared source of truth;
tool-specific surfaces (`.github/copilot-instructions.md`, chat modes) are generated
from it by `scripts/sync-copilot.mjs`.

## What Vela is

Vela is a .NET framework and CLI for building and shipping Dataverse plugins. The `vela`
CLI is the stable, versioned contract this agentic layer targets. You automate Vela by
composing `vela` commands, never by reaching around the CLI into internal APIs.

## The command surface (verified)

- `vela init` (alias `new`) — scaffold a solution on disk. Never connects to Dataverse.
- `vela add <plugin|customapi|service|test|step|form-script|ribbon-script> <Name>` — add a
  component to a project. Local only.
- `vela models` — generate early-bound C# models, or TypeScript form/table models; or
  `--verify` for drift. **Connects to Dataverse** to read metadata.
- `vela plan` — preview registration changes. **Never writes.** The safe dry run.
- `vela apply` — same inputs as `plan`, but **writes to the org**. Confirmation-gated by
  the CLI itself (typed `yes` on a TTY; refuses non-interactively without `--auto-approve`).
- `vela inspect` — compare local packages against the live environment.
- `vela sign` / `vela logout` / `vela update` / `vela version`.

Exit codes: `0` ok, `2` invalid args, `3` file not found, `4` error, `5` drift
(`models --verify`), `6` Dataverse connection failure. Read them; don't ignore them.

See `references/cli-surface.md` for exact flags and `references/dataverse-gotchas.md`
for the battle-tested pitfalls.

## The build loop (user story → shipped)

Local and reversible up to the gate; the org is only ever touched at `apply`:

```
INTAKE → PLAN → SCAFFOLD → MODEL → IMPLEMENT → VERIFY ──🚧gate🚧── APPLY → REPORT
                (init/add)  (models) (code)     (build +          (human
                                                 dotnet test +     approves)
                                                 vela plan)
```

## Golden rules

1. **The CLI is the contract.** Confirm flags with `vela <command> --help` before
   composing a command. Never invent a flag.
2. **Check the version first.** Run `vela version`. If a skill needs a newer CLI than is
   installed, stop and tell the user to `vela update` rather than working around it.
3. **Announce the skill.** When you start a skill, say `Using <skill> to <purpose>` so the
   run is traceable.
4. **Evidence over claims.** Never say a step passed without the CLI/build/test output that
   proves it. `dotnet test` green, `vela plan` clean — paste the evidence.
5. **Stop before `apply`.** `apply` writes to a live org. Do everything up to and including
   `vela plan` autonomously, then stop and let a human run `apply`. Do not pass
   `--auto-approve` unless the user explicitly authorized it for this run.
6. **Prefer generated code.** Regenerate models; never hand-edit generated files.

## House rules

- Never add an AI co-author trailer or AI attribution to commits or PRs.
- One logical change per commit; ship via a PR, never push to a protected branch.
