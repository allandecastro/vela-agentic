---
name: vela-models
description: Generate strongly-typed models from a Dataverse environment with the Vela CLI — early-bound tables, form models, option sets, in C# or TypeScript. Use when the user needs typed models, table interfaces, or form models generated or refreshed.
---

# Generate typed models

Drive `vela models` to generate early-bound tables, form models, and option sets from a
Dataverse environment, in C# or TypeScript.

## Minimum CLI version

`0.15.0` — run `vela --version` and stop if older.

## When to use

- The user wants typed table/record models or form models generated or refreshed.
- The user wants to verify generated models still match the live environment.

## Steps

1. `vela --version`, then `vela models --help` to confirm the exact flags available
   (for example table vs form generation, and the language selector). Do not assume
   flag names — read them from `--help`.
2. Confirm the target environment and output location with the user before generating.
3. Run the generation command. For large environments, pass the CLI's timeout option so
   long reads do not abort midway.
4. If the user only wants to check drift rather than regenerate, use the CLI's verify
   mode instead of overwriting files.
5. Report what was written and whether it is consistent with the live environment.

## Guardrails

- Generated model files are the source of truth — regenerate, do not hand-edit.
- Never name a committed file `*.generated.cs`; that pattern is gitignored and will
  compile locally but be missing on CI. Follow the CLI's own output naming.
- TypeScript and C# generators share option-set output; regenerate the whole set
  together rather than a single file.
