---
name: vela-apply
description: Use when a built, reviewed, tested Vela plugin needs to be packaged, signed, previewed against, or deployed to a Dataverse environment.
compatibility: "vela CLI >= 0.26.0 (Vela.Plugins >= 0.35.0); dotnet SDK."
---

# Package, preview and apply to a Dataverse org

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Turn reviewed code into a package, preview exactly what it would register with `vela plan`, and
stop at the human apply gate. `solution show`, `plan` and `inspect` only read the org; `apply` writes and
is the gate.

## When to use

- The harness suite is green, analyzers are clean and the review passed, and you need the package
  previewed (always) or deployed (only when a human authorizes it).
- After an authorized apply, to confirm the live registration matches the package (`vela inspect`).

## Process

Announce: `Using vela-apply to <purpose>`.

1. `vela version`; `vela plan --help` / `vela apply --help` / `vela solution --help` / `vela sign --help`
   to confirm flags (or `vela help --json`; `references/cli-surface.md`).
2. **Package** the final code: clear `artifacts/` first (an earlier build leaves a package under the
   same name), then **`dotnet build <Solution>.sln -c Release`**. The scaffold's plugin
   project builds the deployable plugin package on build (`GeneratePackageOnBuild`) into the solution's
   `artifacts/` folder. **Not `dotnet pack`**: run cold it exits 0 with `NU5128` and emits a package with
   **no assembly**. Then check the package really holds your plugin -
   `unzip -l artifacts/<Prefix>.Plugins.<ver>.nupkg | grep '<Prefix>.Plugins.dll'` - and record its
   path and hash (`shasum -a 256 <pkg>`). This is the artifact everything below refers to. A project
   scaffolded with `--integrations` builds a second package, `<Prefix>.Integrations.<ver>.nupkg`: check,
   hash, sign and preview it the same way.
   **Build it last.** Every Release build that includes the plugin project - including building the
   test project - repacks the package with a **new hash** even without a source change (verified). Run
   the tests first, then this build, then nothing else before `plan`; the human applies that file
   without rebuilding, after checking the hash. (Committing the Build Report afterwards is expected:
   it changes docs only, and the package - which stamps the commit it was built from - stays the one
   recorded by its hash.)
   **Only what the Canvas asks for may be in it:** every plugin and Custom API in the project is
   registered (a leftover experiment, or the demos of a `--samples` scaffold, included).
3. **Sign - when the target org requires signed packages** (or the project already signs):
   `vela sign --package <pkg> --fingerprint <hex>` (certificate store), or `--pfx <file>
   --pfx-credential <target>`. Never put `--pfx-password` on the command line (it lands in shell
   history and logs). Sign **before** `plan`: signing changes the package, and the preview must be of
   the package that will be applied. If no certificate is available to you, do not sign; record
   "unsigned - a human signs before apply" in the Build Report. Secrets via `--pfx-password-env` /
   `--pfx-base64-env`, never inline. When you do not know whether the org
   requires signing, say so (`signed: unknown`) and list it as an open question at the gate.
4. **Resolve the connection** (`references/cli-surface.md`): headless → `DATAVERSE_CONNECTION_STRING`,
   or `--url`/`--tenant-id`/`--client-id` + `DATAVERSE_CLIENT_SECRET`; `-i` only when a human is at a
   browser. Never echo a secret.
5. **Confirm the target solution (read-only):** `vela solution show <uniquename> --json <connection>` →
   `{"solution":"...","publisherPrefix":"..."}`; the prefix must equal the scaffold's `--publisher-prefix`
   (the `VelaPublisherPrefix` the Custom API names carry). Exit `4` = the solution does not exist (Vela
   does not create it): an open question that blocks the gate.
6. **Preview - always:** `vela plan -p <pkg> --solution <uniquename> <connection> --detailed-exitcode --out plan.json`
   on **the packages the Canvas ships** (`-p` repeated when there are several). **`--solution` is required**:
   without it `plan` fails with exit `4` ("no solution publisher prefix ... Re-run with --solution"). Don't
   use `--packages-dir artifacts` blindly: it previews whatever is there. Exit `8` = changes to apply, `0` =
   nothing to do; `--out` keeps the JSON as evidence. Read the changes and every `diagnostics` line (add
   `--strict` to fail on any warning; `info` lines, such as "Plugin assembly ... not found in Dataverse
   (first deployment)", are expected). The JSON's `operations` list is what `apply` would do - a `package`
   operation (create or republish the plugin package) plus **only** what the Canvas ships; an extra `create`
   means something is in the package that should not be. An `update` or `delete` on a registration the
   Canvas does not own (e.g. a step another build deployed in the same assembly) is never waved through:
   record it and make it an open question that blocks the gate. A step with `WithSecureConfigFrom("Name")`
   needs its value at deploy time (`--secure-config Name=@file` or `VELA_SECURE_CONFIG_Name`) - never in the
   command you paste into the report. When you don't hold the value (the usual case: ops keeps the
   secret), preview **without** it: plan then lists "expects the secure configuration 'Name' ... no value was
   given" in `diagnostics`. Keep that line as evidence and record the value as an open item at the gate;
   never pass a placeholder or invented value - it silences the diagnostic and previews a configuration
   nobody will deploy. Shape in `references/cli-surface.md`. If the connection genuinely fails
   (exit `6`), record the exact command and its exit code as `plan_preview: unavailable`.
7. **Summarise** exactly what `apply` would change in the Build Report's **Gate** section
   (`references/build-report-template.md`): package path + hash, signed or not, the solution, the plan's
   `operations`, and the hash check the human runs first (`shasum -a 256 <pkg>`).
8. **Stop here by default.** Do not run `apply`. Let the human run it, or wait for an explicit "go
   ahead and apply" **for this run**. "Ship it", "looks good", "merge it" or a ready/merged PR are
   not that: they are about the code, not a write to the org.
9. If (and only if) authorized: `vela apply -p <pkg> --solution <uniquename> <connection>` - the same
   package (same hash), the same `--solution`, `--secure-config` **and connection** (`--url <org>`) as the plan -
   never a bare `-i`, which targets whatever org vela last remembered. Every written component is
   added to that solution. On a TTY it still requires a typed `yes`; non-interactive it refuses. Never pass
   `--auto-approve`/`--yes` unless the user asked for an unattended apply. (`--batch-size` only tunes the
   ExecuteMultiple chunk size; leave the default unless told otherwise.)
10. **After an apply:** read what was done from the apply JSON's **`executed`** block (`created`, `updated`,
    `deleted`, `packageRepublished`, `addedToSolution`, `byKind`) - its `summary` is what *remains*
    afterwards, so `added: 0` is the expected result of a successful create, not a no-op. Then
    `vela inspect -p <pkg> --solution <uniquename> <connection>` - the live registration must now match the
    package (`current` vs the package, no diagnostics). Surface any difference.
11. Read every exit code and surface non-zero ones verbatim: `3` package not found, `4` error (incl.
    `--strict`, missing `--solution`), `5` apply not converged (the org still differs after the write - report,
    don't call it done), `6` connection failure, `7` partial apply (some operations failed: read the failure,
    fix the cause, then re-run `apply` - every operation is an idempotent upsert, so the re-run reconciles).

## Rationalizations (excuse → rebuttal)

- "The plan looks fine, I'll just apply." → `apply` writes to a live org. That is the human
  gate; stop and hand off.
- "I'll pass --auto-approve to avoid the prompt." → The prompt is the safety. Only bypass it
  when the user explicitly authorized unattended apply for this run.
- "I ran `plan` earlier, before the review fixes." → The preview is of a package that no longer
  exists. Any code change after the preview: re-run the tests, analyzers and review, rebuild the
  package, re-sign, re-plan. The file name does not change between builds - "same package" means
  **same sha256**.
- "The user said ship it." → That approves the change, not a write to a live org. Hand over the
  exact `vela apply` command.
- "The guard hook blocks me; I'll set `VELA_APPLY_APPROVED=1`." → Only a human sets it, when starting
  the session. Never set it, export it, or route around the hook.
- "Signing is a deploy detail, I'll sign after the preview." → Signing produces a different
  package; preview the signed one.
- "A failed chunk is probably transient, retry." → Exit `7` means re-run *after* fixing the cause: read
  the reported failure first; do not blind-retry a partial write.
- "`plan` failed on `--solution`, I'll preview without it." → It cannot: the package needs the solution's
  publisher prefix. Confirm the solution with `vela solution show`.

## Red flags

- A plan run with a placeholder secure-config value (`--secure-config Name=@dummy`) to make a diagnostic go away.
- Running `apply` without a preceding clean `vela plan` **on the same package** (same hash).
- A code change, rebuild or re-sign after the `plan` without new tests, review and `plan`.
- `dotnet pack` for the plugin package, or a package whose `unzip -l` has no `<Prefix>.Plugins.dll`.
- Setting or exporting `VELA_APPLY_APPROVED` yourself, or retrying a denied `vela apply` another way.
- `--pfx-password` or `--client-secret <value>` on a command line.
- Passing `--auto-approve` without explicit authorization.
- Reporting success on a partial/failed batch (exit `7`) or a non-converged apply (exit `5`), or from
  `summary` instead of `executed`.
- `vela plan` without `--solution`, or a `plan` and `apply` with different `--solution` values.

## Verification

- The Build Report names the package (path + hash), whether it is signed, and carries the `vela plan`
  output for that package with `--solution` and its exit code (or `unavailable` with the exact command
  and exit code when the connection failed), and the `vela solution show` result.
- If applied: the CLI's success confirmation is captured, partial failures are surfaced, and
  `vela inspect` shows no difference between the package and the org; the report cites `executed`.
