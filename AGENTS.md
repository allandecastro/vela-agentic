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

- `vela init` (alias `new`) - scaffold a solution on disk. Never connects to Dataverse.
- `vela add <plugin|customapi|service|test|step|form-script|ribbon-script> <Name>` - add a
  component to a project. Local only.
- `vela models` - generate early-bound C# models, or TypeScript form/table models; or
  `--verify` for drift. **Connects to Dataverse** to read metadata.
- `vela plan` - preview registration changes. **Never writes.** The safe dry run.
- `vela apply` - same inputs as `plan`, but **writes to the org**. Confirmation-gated by
  the CLI itself (typed `yes` on a TTY; refuses non-interactively without `--auto-approve`).
- `vela inspect` - compare local packages against the live environment.
- `vela sign` / `vela logout` / `vela update` / `vela version`.

Exit codes: `0` ok, `2` invalid args, `3` file not found, `4` parse/read error, `5` drift
(`models --verify`), `6` Dataverse connection failure. Read them; don't ignore them.

References: `cli-surface.md` (exact flags), `plugin-authoring-api.md` + `harness-api.md`
(verbatim code), `dataverse-gotchas.md` (pitfalls), `registration-rules.md` (legal matrix +
Sync/Async + reuse/service decisions), `review-checklist.md` (the review axes),
`build-report-template.md` (the Vela Canvas + Build Report).

## The build loop (user story → shipped)

Local and reversible up to the apply gate; the org is only ever touched at `apply`. Two gates:
an advisory **plan gate** at the front and a blocking **apply gate** at the end.

```
INTAKE → PLAN → CHALLENGE ··plan gate·· SCAFFOLD → MODEL → TEST(RED) → IMPLEMENT → VERIFY → REVIEW ──apply gate── APPLY → REPORT
                (self-grill  (advisory:  (init/add) (models) (write     (code to   (suite     (code       (human       (only if
                 declare      flag +                          FAILING    green)     green +    review:     approves)    authorized)
                 acceptance   continue)                       harness               analyzers  spec +
                 cases)                                       tests)                clean)     standards)
```

**Test-first is mandatory.** After MODEL, write the harness tests for the declared acceptance
cases and watch them **fail (RED)** before writing plugin logic; then implement to **green**.
Tests are not optional and not written after the fact - they are the acceptance criteria and
the quality signal.

- **Front (plan gate) is advisory**: self-grill the plan (`vela-plan-review`), fill the **Vela
  Canvas** (a REASONS-adapted spec: Requirements/Entities/Approach/Structure/Operations/Norms/
  Safeguards - the home for the Sync-vs-Async, reuse-vs-new, service, naming and safeguard
  decisions), flag assumptions, and **continue** - do not block. A human may interrupt.
- **The Canvas is a living spec (fix-spec-first).** If the requirement changes mid-build, update
  the Canvas **before** the code; if you refactor without changing behaviour, update the code then
  **sync** it back into the Canvas. The Canvas stays an accurate record of the current plugin.
- **Review before the apply gate**: once tests are green and analyzers clean, review the diff
  (`vela-code-review`) on two axes - **spec** (the Plan artifact's acceptance cases + the
  `dataverse-gotchas` checklist) and **standards** (analyzer intent + the Dataverse smell
  baseline). Critical/Required findings block the gate.
- **End (apply gate) is blocking**: emit a **Build Report**, stop, let a human run `apply`.
- Artifacts (see `references/build-report-template.md`) are committed in the target project
  under `docs/vela-builds/<slug>.md` and reused as the PR body.

## Golden rules

1. **The CLI is the contract.** Confirm flags with `vela <command> --help` before
   composing a command. Never invent a flag.
2. **Check the version.** Run `vela version`. Each skill states its floor in the `compatibility`
   frontmatter (the verified version is recorded in `references/cli-surface.md`). If the installed
   CLI is at or above it, proceed. If it is older, tell the user to `vela update`; only **stop** if a
   *named* feature the skill depends on is genuinely missing. Do not halt merely because the patch
   version differs (e.g. 0.19.4 vs 0.19.5 is fine).
3. **Announce the skill.** When you start a skill, say `Using <skill> to <purpose>` so the
   run is traceable.
4. **Evidence over claims.** Never say a step passed without the CLI/build/test output that
   proves it. `dotnet test` green, `vela plan` clean - paste the evidence.
5. **Quality gate before the apply gate.** The apply gate is unreachable unless: the full
   harness suite is **green** and covers every declared acceptance case; the **authored code**
   (your plugin + your tests) has **no analyzer (VELA00x) violations**; **and** the diff has
   passed **code review** (`vela-code-review`) with no unresolved Critical/Required findings. A
   happy-path-only test, a red test, an analyzer violation, or an unresolved Critical/Required
   review finding blocks the gate. The scaffold's own demo files may carry cosmetic VELA013 -
   clean or remove demo files for a real project, but never let a demo warning mask a real
   violation in your code. The Build Report records all three.
6. **Stop before `apply`.** `apply` writes to a live org. Do everything up to and including
   `vela plan` autonomously, then stop and let a human run `apply`. Do not pass
   `--auto-approve` unless the user explicitly authorized it for this run. An **optional hook**
   (`hooks/`, dual-target Claude Code + Copilot) can enforce this deterministically - it **denies**
   `vela apply` unless `VELA_APPLY_APPROVED=1`. The rule holds whether or not the hook is installed.
7. **Prefer generated code.** Regenerate models; never hand-edit generated files.

## Evidence (claim → proof)

"Evidence over claims" is a procedure, not a vibe. For each claim, the proof is mandatory before
you may state it; skipping the proof is lying, not verifying. Ban "should / probably / seems" -
confidence is not evidence, and a partial run proves nothing.

| Claim | Required proof |
| --- | --- |
| "It builds" | `dotnet build` summary: 0 errors, and 0 analyzer (VELA00x) violations in authored code |
| "Tests pass" | the test runner's summary line + the runner used, and the green cases equal the declared acceptance cases |
| "Bug fixed" | the failing repro test (RED) now passes (GREEN) |
| "Reviewed" | the `vela-code-review` findings list, with no unresolved Critical/Required |
| "Deploy preview is clean" | the `vela plan` output (or "skipped - no org", with the exact command) |

## Environment (local, fleet, cloud)

The stop-before-apply boundary holds identically whether run by a human, a fleet worker, or a
cloud agent. Prerequisites for a non-interactive or remote environment:

- **The pack must be reachable.** Locally, point at this repo. On another machine or in the
  cloud, install it as a plugin marketplace (**requires the repo to be pushed**) or make sure
  the workspace carries `skills/` + `agents/` + `AGENTS.md`. Each skill bundles the references it
  cites under `skills/<name>/references/`, so skills installed alone (e.g. `gh skill install`) still
  have them.
- **Toolchain present.** Install the `vela` global tool (`dotnet tool install --global Vela.Cli`)
  and a matching `dotnet` SDK. If missing, stop and say so - do not improvise an alternative.
- **Non-interactive auth (no browser).** `-i`/`--interactive` needs a screen and won't work
  headless. Use `DATAVERSE_CONNECTION_STRING`, or `--url` + `--tenant-id` + `--client-id` with
  the secret via `DATAVERSE_CLIENT_SECRET` / `--client-secret-stdin`, or `DefaultAzureCredential`
  (managed identity / `az login`). See `references/cli-surface.md`. Never echo a secret to logs.
- **Test runner by OS.** net462 tests: Windows can `dotnet test`; Linux/macOS need Mono +
  xunit console `-parallel none` (see `references/harness-api.md`).
- **Never auto-`apply`.** Even unattended, stop at the gate; only pass `--auto-approve` if the
  user explicitly authorized an unattended apply for that run.

## House rules

- Never add an AI co-author trailer or AI attribution to commits or PRs.
- One logical change per commit; ship via a PR, never push to a protected branch.
