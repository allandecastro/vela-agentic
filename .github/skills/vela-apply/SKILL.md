---
name: vela-apply
description: Use when a built, reviewed, tested Vela plugin needs to be packaged, signed, previewed against, or deployed to a Dataverse environment.
compatibility: "vela CLI >= 0.19.6 (Vela.Plugins >= 0.28.2); dotnet SDK."
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
2. **Package** the final code: **`dotnet build <Solution>.sln -c Release`**. The scaffold's plugin
   project builds the deployable plugin package on build (`GeneratePackageOnBuild`) into the solution's
   `artifacts/` folder. **Not `dotnet pack`**: run cold it exits 0 with `NU5128` and emits a package with
   **no assembly** (verified, scaffold 0.19.6). Then check the package really holds your plugin -
   `unzip -l artifacts/<Prefix>.Plugins.<ver>.nupkg | grep '<Prefix>.Plugins.dll'` - and record its
   path and hash (`shasum -a 256 <pkg>`). This is the artifact everything below refers to.
   **Build it last.** Every Release build that includes the plugin project - including building the
   test project - repacks the package with a **new hash** even without a source change (verified). Run
   the tests first, then this build, then nothing else before `plan`; the human applies that file
   without rebuilding, after checking the hash. (Committing the Build Report afterwards is expected:
   it changes docs only, and the package - which stamps the commit it was built from - stays the one
   recorded by its hash.)
   **Only what the Canvas asks for may be in it:** the scaffold's demo plugins and Custom APIs (e.g. an
   Account create step, `Ping`) are registered too if they are still in the project - remove them
   for a real project (`vela-scaffold`).
3. **Sign - when the target org requires signed packages** (or the project already signs):
   `vela sign --package <pkg> --fingerprint <hex>` (certificate store), or `--pfx <file>
   --pfx-credential <target>`. Never put `--pfx-password` on the command line (it lands in shell
   history and logs). Sign **before** `plan`: signing changes the package, and the preview must be of
   the package that will be applied. If no certificate is available to you, do not sign; record
   "unsigned - a human signs before apply" in the Build Report.
4. **Resolve the connection** (`references/cli-surface.md`): headless → `DATAVERSE_CONNECTION_STRING`,
   or `--url`/`--tenant-id`/`--client-id` + `DATAVERSE_CLIENT_SECRET`; `-i` only when a human is at a
   browser. Never echo a secret.
5. **Preview - always:** `vela plan -p <pkg> <connection> --out plan.json` on **the packages the Canvas
   ships** - the plugin package, plus the Integrations package only when the Canvas has an outbound
   flow (`-p` repeated). Don't use `--packages-dir artifacts` blindly: it previews whatever is there. Output is JSON when piped;
   `--out` keeps it as evidence. Read the changes and every diagnostic (add `--strict` to fail on
   any). `plan` does **not** tag a solution - do not pass `--solution` to it (apply-only). No org
   available → record `skipped - no org` and the exact command that would have run.
6. **Summarise** exactly what `apply` would change in the Build Report's **Gate** section
   (`references/build-report-template.md`): package path + hash, signed or not, the plan diff, and the
   hash check the human runs first (`shasum -a 256 <pkg>`). If the build used a no-org model stand-in,
   the Gate says so: regenerating the models with `vela models` is a code change - rebuild, re-test,
   re-plan, and apply **that** package, not this one.
7. **Stop here by default.** Do not run `apply`. Let the human run it, or wait for an explicit "go
   ahead and apply" **for this run**. "Ship it", "looks good", "merge it" or a ready/merged PR are
   not that: they are about the code, not a write to the org.
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
  exists. Any code change after the preview: re-run the tests, analyzers and review, rebuild the
  package, re-sign, re-plan. The file name does not change between builds - "same package" means
  **same sha256**.
- "The user said ship it." → That approves the change, not a write to a live org. Hand over the
  exact `vela apply` command.
- "The guard hook blocks me; I'll set `VELA_APPLY_APPROVED=1`." → Only a human sets it, when starting
  the session. Never set it, export it, or route around the hook.
- "Signing is a deploy detail, I'll sign after the preview." → Signing produces a different
  package; preview the signed one.
- "A failed chunk is probably transient, retry." → Read the reported failure first; do not
  blind-retry a partial write.

## Red flags

- Running `apply` without a preceding clean `vela plan` **on the same package** (same hash).
- A code change, rebuild or re-sign after the `plan` without new tests, review and `plan`.
- `dotnet pack` for the plugin package, or a package whose `unzip -l` has no `<Prefix>.Plugins.dll`.
- Setting or exporting `VELA_APPLY_APPROVED` yourself, or retrying a denied `vela apply` another way.
- `--pfx-password` or `--client-secret <value>` on a command line.
- Passing `--auto-approve` without explicit authorization.
- Reporting success on a partial/failed batch.

## Verification

- The Build Report names the package (path + hash), whether it is signed, and carries the `vela plan`
  output for that package (or `skipped - no org` with the exact command).
- If applied: the CLI's success confirmation is captured, partial failures are surfaced, and
  `vela inspect` shows no difference between the package and the org.
