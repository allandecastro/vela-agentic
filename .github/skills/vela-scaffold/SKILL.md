---
name: vela-scaffold
description: Scaffold a new Vela plugin project or add a plugin message/component to an existing one. Use when the user wants to start a Vela project, add a plugin step, or generate boilerplate that compiles and applies unedited.
---

# Scaffold Vela projects and components

Drive the `vela` CLI to create a new plugin project or add components to an existing
one. Generated code must compile and apply **without hand edits** — that is the
contract of Vela's scaffolding.

## Minimum CLI version

`0.15.0` — run `vela --version` and stop if older.

## When to use

- The user wants to start a new Vela plugin project.
- The user wants to add a plugin message, custom API, or ribbon script to an existing
  Vela project.

## Steps

1. Confirm the CLI is present and new enough: `vela --version`.
2. Discover the exact subcommands and flags — **do not guess**:
   `vela --help`, then `vela <command> --help` for the scaffold/add command shown.
3. Determine the target: a new project (empty directory) or an existing Vela project
   (look for the project's `.csproj` and Vela packages first).
4. Run the scaffold/add command with the flags confirmed in step 2.
5. Build to prove the generated code compiles. Report the exact build output.
6. Summarize what was generated and the follow-up commands (for example applying the
   change to an org via the `vela-apply` skill).

## Guardrails

- Never hand-edit generated files to make them compile; if they do not compile, that is
  a bug to report, not to patch around.
- Adding a typed plugin message touches several files that must stay in sync; rely on
  the CLI's `add` command to keep them consistent rather than editing by hand.
