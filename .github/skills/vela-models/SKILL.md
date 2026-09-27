---
name: vela-models
description: Use when a plugin needs typed models for an attribute or entity not yet in the generated model, or when checking whether committed models still match the org.
compatibility: "vela CLI >= 0.19.4 (Vela.Plugins >= 0.28.2); dotnet SDK."
---

# Generate typed models

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Drive `vela models` to generate early-bound C# models or TypeScript form/table models from
a Dataverse environment, or to verify drift. This command **connects to Dataverse** to read
metadata, so it needs a resolved connection.

## When to use

- You need typed models for the entities a plugin touches.
- You want to check whether committed models still match the live org (`--verify`).

## Process

Announce: `Using vela-models to <purpose>`.

1. `vela version`; `vela models --help` to confirm flags.
2. **Choose a scope - it is required.** One of `--solution <name>`, `--entities a,b`,
   `--custom-apis`, `--messages`, `--roles`, `--solution-roles`. The command refuses to
   generate every table.
3. Resolve the connection (see `references/cli-surface.md`): interactive `-i` for a dev org,
   or connection string / client secret for automation.
4. Generate:
   - C# early-bound (default): `vela models --entities account,contact -i`
   - TypeScript: add `--forms` and/or `--tables`.
   - Large orgs: pass `--timeout <minutes>`.
5. **Verify mode** (no write): `vela models --verify ...` - exit `5` means drift.
6. **Detect an absent table/attribute** (to decide whether an AC is buildable): probe it with
   `vela models --entities <name>`. A missing entity prints `Could not find an entity` to stdout
   (exit can still be `0`), so **check the output text, not just the exit code**. An absent
   dependency means the AC that needs it is excluded from v1 (record it in the Canvas), never invented.
7. Report what was written (or the drift) and where.

## Rationalizations (excuse → rebuttal)

- "I'll just hand-write the model class." → Generated models are the source of truth and
  stay in sync with the org; hand-written ones rot. Generate.
- "No scope needed, generate everything." → The command refuses that on purpose; pick a
  real scope.
- "Drift is probably fine." → `--verify` exited 5 for a reason. Regenerate or explain.

## Red flags

- A committed model file named `*.generated.cs` (gitignored - will be missing on CI).
- You are about to combine `--verify` with `--forms`/`--tables` (not allowed).
- Editing a generated model instead of regenerating.

## Verification

- The command exits `0` and the files exist where it reported.
- For drift checks, `vela models --verify` exits `0` (no drift). A `5` must be resolved,
  a `6` is a connection failure to surface.
