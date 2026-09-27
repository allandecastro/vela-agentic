---
name: vela-apply
description: Use when a built, reviewed, tested Vela plugin needs to be packaged, signed, previewed against, or deployed to a Dataverse environment.
compatibility: "vela CLI >= 0.19.4 (Vela.Plugins >= 0.28.2); dotnet SDK."
---

# Package, preview and apply to a Dataverse org

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Turn reviewed code into a package, preview exactly what it would register with `vela plan`, and
stop at the human apply gate. `plan` and `inspect` only read the org; `apply` writes and is the gate.

## When to use

- The harness suite is green, analyzers are clean and the review passed, and you need the package
  previewed (always) or deployed (only when a human authorizes it).
- After an authorized apply, to confirm the live registration matches the package (`vela inspect`).

## Process

Announce: `Using vela-apply to <purpose>`.

1. `vela version`; `vela plan --help` / `vela apply --help` / `vela sign --help` to confirm flags
   (`references/cli-surface.md`).
2. **Package** the final code: `dotnet pack` as the project defines (e.g. `-c Release`). Record the
   `.nupkg` path and its hash (`shasum -a 256 <pkg>`). This is the artifact everything below refers to.
3. **Sign - when the target org requires signed packages** (or the project already signs):
   `vela sign --package <pkg> --fingerprint <hex>` (certificate store), or `--pfx <file>
   --pfx-credential <target>`. Never put `--pfx-password` on the command line (it lands in shell
   history and logs). Sign **before** `plan`: signing changes the package, and the preview must be of
   the package that will be applied. If no certificate is available to you, do not sign; record
   "unsigned - a human signs before apply" in the Build Report.
4. **Resolve the connection** (`references/cli-surface.md`): headless → `DATAVERSE_CONNECTION_STRING`,
   or `--url`/`--tenant-id`/`--client-id` + `DATAVERSE_CLIENT_SECRET`; `-i` only when a human is at a
   browser. Never echo a secret.
5. **Preview - always:** `vela plan -p <pkg> <connection> --out plan.json`. Output is JSON when piped;
   `--out` keeps it as evidence. Read the changes and every diagnostic (add `--strict` to fail on
   any). `plan` does **not** tag a solution - do not pass `--solution` to it (apply-only). No org
   available → record `skipped - no org` and the exact command that would have run.
6. **Summarise** exactly what `apply` would change in the Build Report's **Gate** section
   (`references/build-report-template.md`): package path + hash, signed or not, the plan diff.
7. **Stop here by default.** Do not run `apply`. Let the human run it, or wait for an explicit "go
   ahead and apply" for this run.
8. If (and only if) authorized: `vela apply -p <pkg> --solution <uniquename> <connection>`.
   **`--solution` is required here** (apply-only): every component is tagged into that solution;
   without it they fall into the default solution. The solution + its publisher must already exist
   (Vela doesn't create them), and the scaffold `--prefix` must match its publisher prefix
   (`references/registration-rules.md`). On a TTY it still requires a typed `yes`; non-interactive it
   refuses. Never pass `--auto-approve`/`--yes` unless the user asked for an unattended apply.
9. **After an apply:** `vela inspect -p <pkg> <connection>` - the live registration must now match
   the package. Surface any difference.
10. Read every exit code and surface non-zero ones verbatim (`3` package not found, `4` parse/read
    error, `6` connection failure).

## Rationalizations (excuse → rebuttal)

- "The plan looks fine, I'll just apply." → `apply` writes to a live org. That is the human
  gate; stop and hand off.
- "I'll pass --auto-approve to avoid the prompt." → The prompt is the safety. Only bypass it
  when the user explicitly authorized unattended apply for this run.
- "I ran `plan` earlier, before the review fixes." → The preview is of a package that no longer
  exists. Re-pack, re-sign, re-plan.
- "Signing is a deploy detail, I'll sign after the preview." → Signing produces a different
  package; preview the signed one.
- "A failed chunk is probably transient, retry." → Read the reported failure first; do not
  blind-retry a partial write.

## Red flags

- Running `apply` without a preceding clean `vela plan` **on the same package** (same hash).
- A code change, re-pack or re-sign after the `plan` without a new `plan`.
- `--pfx-password` or `--client-secret <value>` on a command line.
- Passing `--auto-approve` without explicit authorization.
- Reporting success on a partial/failed batch.

## Verification

- The Build Report names the package (path + hash), whether it is signed, and carries the `vela plan`
  output for that package (or `skipped - no org` with the exact command).
- If applied: the CLI's success confirmation is captured, partial failures are surfaced, and
  `vela inspect` shows no difference between the package and the org.
