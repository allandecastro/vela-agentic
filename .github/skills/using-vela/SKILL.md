---
name: using-vela
description: Read first when starting any Vela work, or when unsure which Vela skill applies.
compatibility: "vela CLI >= 0.27.0 (Vela.Plugins >= 0.39.0); dotnet SDK."
---

# Using Vela

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Meta-skill: how to drive Vela through its CLI. Read this before the other Vela skills.

## The build loop

Local and reversible until the gate; the org is only written at `apply`. One skill per step:

1. **Intake** - concrete spec (entity, message, images, rules).
2. **Plan** - scaffold or existing project, models, logic.
3. **Challenge** - `vela-plan-review`: self-grill, fill the **Vela Canvas**, flag assumptions, continue
   (advisory). Only the human can resolve it? `vela-grill`. A changed requirement updates the Canvas
   before the code.
4. **Scaffold** - `vela-scaffold`: `vela solution show` → `vela init` (minimal) → models → `vela add`.
5. **Model** - `vela-models`, before the first plugin (no models, no compile).
6. **Test (RED)** - `vela-test-harness`: failing tests for the acceptance cases, seen to fail. Mandatory.
7. **Implement** - `vela-plugin-authoring` until **green**.
8. **Verify** - suite green **and** no analyzer (VELA00x) violations.
9. **Review** - `vela-code-review` via the isolated `vela-reviewer`; open Critical/Required block.
10. **Package & preview** - `vela-apply`: `dotnet build -c Release` → `vela sign` if required →
    `vela plan --solution <uniquename>` (never writes). Last: a later code change means re-test,
    re-review, rebuild, re-plan.
11. **Apply gate** - emit the **Build Report**, stop. A human runs `vela apply`.
12. **Report** - PR with the Build Report as body.

A callable operation (inputs → outputs): `vela-custom-api` drives the same loop. Misbehaviour:
`vela-debug-plugin` (`vela logs`, read-only).

## Skills, agents and how they run

Every skill is model-invoked (a human may also run one as a slash command, e.g. `/vela-grill` - the
conversation with the human). `vela-builder` (the end-to-end loop) and `vela-reviewer` (isolated review)
are agents; there is no build or apply slash command.

## Non-negotiable rules

- **The CLI is the contract.** Confirm flags with `vela <command> --help` (or `vela help --json`). For framework API
  detail this pack doesn't carry, read Vela's own docs: `https://raw.githubusercontent.com/allandecastro/vela/main/docs/llms.txt`
  (index of the guides) - don't guess an API.
- **Version first.** `vela version` before relying on a feature.
- **Announce the skill.** `Using <skill> to <purpose>`.
- **Evidence over claims.** Paste the build/test/plan output.
- **Stop before `apply`.** No live-org write without explicit human go-ahead; no `--auto-approve`
  unless told for this run.
- **This pack governs.** Where the `AGENTS.md` that `vela init` writes differs (e.g. `vela models
  --interactive`), the skills win.

## References

- `references/cli-surface.md` - exact commands and flags.
- `references/dataverse-gotchas.md` - the real failure modes.
