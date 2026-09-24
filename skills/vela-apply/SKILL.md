---
name: vela-apply
description: Apply a Vela project's changes to a Dataverse environment — registering steps, deploying plugins, and batching writes. Use when the user wants to deploy or apply their Vela project to a real org. Outward-facing; confirm before running.
---

# Apply changes to a Dataverse environment

Drive `vela apply` (and related deploy commands) to push a Vela project's registered
steps and plugins to a Dataverse org. Writes are batched through chunked
`ExecuteMultiple` with per-owner reporting and a fallback path.

## Minimum CLI version

`0.15.2` — run `vela --version` and stop if older.

## When to use

- The user wants to deploy or apply their Vela project to a real Dataverse org.

## Steps

1. `vela --version`, then `vela apply --help` (and `vela --help`) to confirm the exact
   command and flags for the installed version.
2. Identify the target environment and authenticate via the CLI's own auth flow. Never
   handle raw secrets yourself.
3. **Confirm before mutating.** Summarize what will be registered/changed and get the
   user's explicit go-ahead. This command writes to a live org.
4. Run the apply command. Pass the timeout option for large batches.
5. Read the per-owner batch report the CLI emits. If any chunk fell back or failed,
   surface that verbatim — do not report success on partial completion.

## Guardrails

- This is an outward-facing, hard-to-reverse action. Confirm first unless the user has
  explicitly authorized proceeding.
- Do not retry a failed batch blindly; inspect the CLI's reported failure first.
