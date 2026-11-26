---
name: vela-apply
description: Use when a built, reviewed, tested Vela plugin needs to be packaged, signed, previewed against, or deployed to a Dataverse environment.
compatibility: "vela CLI + dotnet SDK."
license: MIT
metadata:
  version: "0.1.9"
---

# Package, preview and apply to a Dataverse org

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Package reviewed code, preview it with `vela plan`, stop at the human apply gate. Only `apply` writes.

## When to use

- Suite green, analyzers clean, review passed: preview the package (always) or deploy it (only when a
  human authorizes it).
- After an authorized apply, to confirm the live registration matches the package (`vela inspect`).

## Process

Announce: `Using vela-apply to <purpose>`. Flags and JSON shapes: `vela <cmd> --help` and
`references/cli-surface.md`.

1. `vela version`; confirm flags with `--help`.
2. **Package** - clear `artifacts/` (an earlier build leaves a package under the same name), then
   `dotnet build <Solution>.sln -c Release` (the plugin project packs on build into `artifacts/`).
   **Not `dotnet pack`**: run cold it exits 0 with `NU5128` and a package with **no assembly**. Check it:
   `unzip -l artifacts/<PackageId>.<ver>.nupkg | grep '<Prefix>.Plugins.dll'`, and record path + hash
   (`shasum -a 256 <pkg>`). An `--integrations` project builds a second `<Prefix>.Integrations.<ver>.nupkg`:
   treat it the same way.
   - **Build it last.** Any Release build including the plugin project (tests too) repacks with a **new
     hash**, even unchanged. Tests, then this build, then `plan`. (Committing the Build Report after is fine.)
   - **Only what the Canvas asks for:** every plugin and Custom API in the project gets registered.
3. **Sign - when the org requires signed packages** (or the project already signs), **before** `plan`
   (signing changes the package). `vela sign --package <pkg> --fingerprint <hex>` or `--pfx <file>
   --pfx-credential <target>`; secrets via `--pfx-password-env` / `--pfx-base64-env`, never
   `--pfx-password` on a command line. No certificate → don't sign; record "unsigned - a human signs
   before apply". Unknown whether signing is required → `signed: unknown`, an open question at the gate.
   Sign only a package whose id already carries the publisher prefix (`<prefix>_<Package>`, e.g.
   `zava_Zava.Integrations`): `apply --solution` adds a missing prefix by rewriting the package, which would
   break the signature, so it refuses a signed package without one.
4. **Connection** (`references/cli-surface.md`): headless (connection string, client secret env, or
   `--url` + `az login`); `-i` only with a human at a browser. Never echo a secret.
5. **Confirm the solution (read-only):** the package's solution from `PROJECT.md` (`packages:`), then `vela solution
   show <uniquename> --json <connection>`; its `publisherPrefix` must equal `PROJECT.md`'s. Exit `4` = no such solution (Vela
   does not create it): ask the human for the right unique name (one question); none reachable → an open question
   that blocks the gate.
6. **Preview - always:** `vela plan -p <pkg> --solution <uniquename> <connection> --detailed-exitcode --out .vela-runs/<slug>/plan.json`
   on **the packages the Canvas ships** (`-p` repeated; not `--packages-dir artifacts` blindly).
   `--solution` is required (else exit `2`, before connecting). First write to `.vela-runs/`: add it to the
   project's `.gitignore`. An org the human did not name (taken from `~/.vela/config.json` or an earlier run)
   is recorded as `org: unconfirmed` and asked at the gate. A package with nothing of yours (empty `<P>.Plugins` beside
   an Integrations-only story) is not created; include or omit it consistently, recorded in the Canvas.
   - Read every `diagnostics` line. `operations` must be a `package` operation plus **only** what the
     Canvas ships: an extra `create` is something that should not be in the package; an `update`/`delete`
     on a registration the Canvas does not own is an open question that blocks the gate. A Canvas step
     **missing** from `operations` (e.g. "contains no plugin", even with exit 0) is not a clean preview:
     find out why before the gate, or report it as a blocker.
   - `WithSecureConfigFrom("Name")` needs its value at deploy time (`--secure-config Name=@file` or
     `VELA_SECURE_CONFIG_Name`), never in a pasted command. Not holding it (usual) → preview **without**
     it, keep the "expects the secure configuration" diagnostic, record the value as an open item.
     **Never a placeholder value** - it silences the diagnostic and previews a config nobody deploys.
   - A story that leaves the package with **no plugin** (all removed): `plan` creates nothing and deletes
     nothing - the deployed steps stay; record them at the Gate for a human to unregister.
   - Exit `4` - refused before any write; its message names the cause (`references/cli-surface.md`). A solution
     **managed** there → the connection points at a test/production org: ask the human for the development org.
     Any other cause is the package's: fix it, rebuild, re-plan.
   - Exit `6` (connection genuinely failed) → `plan_preview: unavailable` with the exact command + exit code.
7. **Summarise** in the Build Report's **Gate** section (`references/build-report-template.md`): the apply
   command, the rollback and its limits, and the check on the org when the harness cannot prove the story. The registry is
   not touched here (written at design, read-only in the build except its trace lines); it carries no
   deploy status - merging the PR puts the rules in force, the Build Report's `apply:` records the deploy.
8. **Stop here by default.** No `apply` unless an explicit "go ahead and apply" **for this run**. "Ship
   it", "looks good", "merge it" or a merged PR approve the code, not a write to the org.
9. If (and only if) authorized: `vela apply -p <pkg> --solution <uniquename> <connection>` - same package
   (same hash), same `--solution`, `--secure-config` **and connection** (`--url <org>`) as the plan; never a
   bare `-i` (it targets the last remembered org). `--auto-approve` only for an authorized unattended apply.
10. **After an apply:** report from the JSON's **`executed`** block, not `summary` (that is what
    *remains*: `added: 0` after a successful create). Then `vela inspect -p <pkg> --solution <uniquename>
    <connection>` must show no difference; surface any.
11. Surface every non-zero exit verbatim: `5` = not converged (not done); `7` = partial - fix the
    cause, re-run `apply` (idempotent upserts).

## Rationalizations (excuse → rebuttal)

- "Exit `4`, the plugin is just not deployed there." → Exit `4` is a missing or managed solution (wrong org) or a
  package `plan` refuses - read its message; never record the preview as merely unavailable.
- "The plan looks fine, I'll just apply." / "I'll pass --auto-approve." → `apply` writes to a live org;
  the prompt is the safety. Stop and hand off.
- "I ran `plan` earlier, before the review fixes." → That package no longer exists. Any code change:
  re-run tests, analyzers, review, rebuild, re-sign, re-plan. "Same package" means **same sha256**.
- "The user said ship it." → That approves the change, not a write. Hand over the exact `vela apply`.
- "The guard hook blocks me; I'll set `VELA_APPLY_APPROVED=1`." → Only a human sets it, at session
  start. Never set, export or route around it.
- "A failed chunk is probably transient, retry." → Exit `7`: fix the reported cause first.
- "`plan` failed on `--solution`, I'll preview without it." → It cannot; check `vela solution show`.

## Red flags

- A placeholder secure-config value (`--secure-config Name=@dummy`) to silence a diagnostic.
- `apply` without a clean `vela plan` on the same package (same hash), or a rebuild / re-sign / code
  change after `plan` without new tests, review and `plan`.
- `dotnet pack`, or a package whose `unzip -l` has no `<Prefix>.Plugins.dll`.
- Setting `VELA_APPLY_APPROVED` yourself, or retrying a denied `vela apply` another way.
- `--pfx-password` or `--client-secret <value>` on a command line; `--auto-approve` without authorization.
- Success reported on exit `7` or `5`, or from `summary` instead of `executed`.
- `plan` without `--solution`, or `plan` and `apply` with different `--solution` values.

## Verification

- The Build Report names the package (path + hash) and its signing state, the `vela solution show`
  result, and the `vela plan --solution` output + exit code (or `unavailable` with command + exit code).
- If applied: success confirmation captured from `executed`, partial failures surfaced, and
  `vela inspect` shows no difference.
