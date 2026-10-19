---
name: vela-models
description: Use when a plugin needs typed models for an attribute or entity not yet in the generated model, or when checking whether committed models still match the org.
compatibility: "vela CLI >= 0.27.3 (Vela.Plugins >= 0.40.0); dotnet SDK."
---

# Generate typed models

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Drive `vela models` to generate typed models or verify drift. It **connects to Dataverse**.

## When to use

- You need typed models for the entities a plugin touches.
- You want to check whether committed models still match the live org (`--verify`).

## Process

Announce: `Using vela-models to <purpose>`. Flags and scopes: `vela models --help`
(`references/cli-surface.md`).

1. `vela version`.
2. **A scope is required** (`--entities`, `--solution`, `--custom-apis`, ...); the command refuses to
   generate every table.
3. **Connection:** headless (`--url <org>` + `az login`, connection string, client secret); `-i` only
   with a human at a browser. A new scaffold has **no models**: no org, no buildable plugin. The only
   offline route: `--from-solution <zip> --namespace <ns> --out <dir>` (only what the solution contains).
   Exit `6` → record the command + exit code and stop the MODEL step; never hand-write a model.
4. **Generate:** `vela models --entities account,contact --project src/<Prefix>.Shared/<Prefix>.Shared.csproj --overwrite <connection>`
   - `--project` = the **Shared** project (its namespace, its `Models/Generated`), not Plugins.
   - Custom APIs from the org, excluding your typed ones: `--custom-apis --package
     artifacts/<Prefix>.Plugins.<ver>.nupkg` (repeat `--package` for the Integrations package).
5. **Verify** (no write): `vela models --verify ...` - exit `5` = drift.
6. **Probe an absent table/attribute** (is an AC buildable?): `vela models --entities <name>`. A missing
   entity prints `Could not find an entity` with exit possibly `0` - **check the text, not just the exit
   code**. An absent dependency excludes its AC from v1 (recorded in the Canvas), never invented.
7. Report what was written (or the drift) and where. Success is the "Generated N file(s)" line, not
   just the exit code.

## Rationalizations (excuse → rebuttal)

- "I'll just hand-write the model class." → Generated models track the org; hand-written ones rot.
- "No org right now - a small stand-in model gets the build going." → Not the org's schema. Generate (or
  `--from-solution`); a failed connection is recorded, not papered over.
- "Drift is probably fine." → `--verify` exited 5 for a reason. Regenerate or explain.

## Red flags

- A committed model file named `*.generated.cs` (often gitignored - missing on CI).
- Editing a generated model instead of regenerating, or hand-writing one when the connection failed.
- Models generated into the Plugins project or the current directory instead of
  `<Prefix>.Shared/Models/Generated`.

## Verification

- Exit `0` and the files exist where reported.
- Drift checks: `vela models --verify` exits `0`; a `5` must be resolved, a `6` surfaced.
