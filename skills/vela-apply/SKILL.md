---
name: vela-apply
description: Use when a built, reviewed, tested Vela package needs to be previewed against or deployed to a Dataverse environment.
compatibility: "vela CLI >= 0.19.4 (Vela.Plugins >= 0.28.2); dotnet SDK."
---

# Preview and apply to a Dataverse org

Drive `vela plan` then `vela apply` to deploy registrations to an org. `plan` is safe and
never writes; `apply` writes and is the human gate of the build loop.

## When to use

- A package is built and harness-green, and you need to preview or deploy it.

## Process

Announce: `Using vela-apply to <purpose>`.

1. `vela version`; `vela plan --help` / `vela apply --help` to confirm flags.
2. Build the package (`dotnet pack` as the project defines) and resolve the connection
   (see `references/cli-surface.md`).
3. **Preview - always:** `vela plan -p <pkg>.nupkg -i`. Read the previewed changes. `plan` never
   writes and does **not** tag a solution - do not pass `--solution` to `plan` (it's apply-only).
4. Summarise exactly what `apply` would change and present it to the user.
5. **Stop here by default.** Do not run `apply`. Let the human run it, or wait for an
   explicit "go ahead and apply" for this run.
6. If (and only if) authorized: `vela apply -p <pkg>.nupkg --solution <uniquename> -i`.
   **`--solution` is required here** (apply-only): every component is tagged into that solution;
   without it they fall into the default solution. The solution + its publisher must already exist
   (Vela doesn't create them), and the scaffold `--prefix` must match its publisher prefix.
   On a TTY it will still require a typed `yes`. Never pass `--auto-approve`/`--yes` unless
   the user asked for unattended apply.
7. Read the result. Surface any non-zero exit (6 = connection failure) verbatim.

## Rationalizations (excuse → rebuttal)

- "The plan looks fine, I'll just apply." → `apply` writes to a live org. That is the human
  gate; stop and hand off.
- "I'll pass --auto-approve to avoid the prompt." → The prompt is the safety. Only bypass it
  when the user explicitly authorized unattended apply for this run.
- "A failed chunk is probably transient, retry." → Read the reported failure first; do not
  blind-retry a partial write.

## Red flags

- Running `apply` without a preceding clean `vela plan`.
- Passing `--auto-approve` without explicit authorization.
- Reporting success on a partial/failed batch.

## Verification

- `vela plan` output presented to the user before any apply.
- If applied, the CLI's success confirmation is captured; partial failures are surfaced, not
  swallowed.
