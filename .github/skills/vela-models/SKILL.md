---
name: vela-models
description: Use when a plugin needs typed models for an attribute or entity not yet in the generated model, or when checking whether committed models still match the org.
compatibility: "vela CLI >= 0.26.2 (Vela.Plugins >= 0.37.0); dotnet SDK."
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
   `--custom-apis`, `--messages`, `--roles`, `--solution-roles` (add `--intersect` for the N:N
   intersect tables of the scoped tables). The command refuses to generate every table.
3. **Resolve the connection** (`references/cli-surface.md`): **`--url <org>` alone** when an `az login`
   session (or managed identity) exists - headless; connection string / client secret for automation;
   interactive `-i` only with a human at a browser. A new scaffold has **no models at all**, so a plugin
   does not compile until this runs - there is no no-org path to a buildable plugin. The only offline
   route is an exported solution zip: `vela models --from-solution <zip> --namespace <ns> --out <dir>` -
   only the tables/columns **the solution contains** (an out-of-box table not in it yields "No table
   metadata ... was found", exit `2`). If the connection genuinely fails (exit `6`), record the exact
   command and its exit code and stop the MODEL step - never hand-write a model.
4. Generate:
   - C# early-bound (default): `vela models --entities account,contact --project src/<Prefix>.Shared/<Prefix>.Shared.csproj --overwrite <connection>`
     - `--project` takes that project's namespace and writes into its `Models/Generated` folder (the
     scaffold's home for models - the Shared project, not the Plugins project). Without `--project`,
     pass `--out <dir>` and `--namespace <ns>`.
   - Custom APIs from the org, excluding the typed ones you author: `vela models --custom-apis --package artifacts/<Prefix>.Plugins.<ver>.nupkg --project ... <connection>`
     (`--package` is repeatable - add the Integrations package when it has typed Custom APIs too).
   - `--no-annotations` omits `[StringLength]`/`[Range]`. TypeScript: `--lang ts` with `--forms` and/or `--tables` (preview).
   - Large orgs: pass `--timeout <minutes>`.
5. **Verify mode** (no write): `vela models --verify ...` - exit `5` means drift.
6. **Detect an absent table/attribute** (to decide whether an AC is buildable): probe it with
   `vela models --entities <name>`. A missing entity prints `Could not find an entity` to stdout
   (exit can still be `0`), so **check the output text, not just the exit code**. An absent
   dependency means the AC that needs it is excluded from v1 (record it in the Canvas), never invented.
7. Report what was written (or the drift) and where. **Check the output text**: a run that generates
   nothing (e.g. "Could not infer a namespace" outside a project without `--project`/`--namespace`,
   exit `2`) is not a success. Success is the "Generated N file(s) into <dir>" line (or `--json`).

## Rationalizations (excuse → rebuttal)

- "I'll just hand-write the model class." → Generated models are the source of truth and
  stay in sync with the org; hand-written ones rot. Generate.
- "No scope needed, generate everything." → The command refuses that on purpose; pick a
  real scope.
- "No org right now - I'll write a small stand-in model to get the build going." → Hand-written models
  are not the org's schema. Generate them (or `--from-solution`); a failed connection is recorded, not
  papered over.
- "Drift is probably fine." → `--verify` exited 5 for a reason. Regenerate or explain.

## Red flags

- A committed model file named `*.generated.cs` (often gitignored - it can be missing on CI).
- You are about to combine `--verify` with `--forms`/`--tables` (not allowed).
- Editing a generated model instead of regenerating, or hand-writing one when the connection failed.
- Models generated into the Plugins project or the current directory instead of `<Prefix>.Shared/Models/Generated`.

## Verification

- The command exits `0` and the files exist where it reported.
- For drift checks, `vela models --verify` exits `0` (no drift). A `5` must be resolved,
  a `6` is a connection failure to surface.
