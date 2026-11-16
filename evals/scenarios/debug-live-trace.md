---
scenario: debug-live-trace
skills_exercised: [vela-debug-plugin, vela-plugin-testing, vela-code-review, vela-apply]
entity: contact
message: Create
gotchas_exercised: [read-the-trace-first, repro-before-fix, minimal-fix, null-in-target]
org_required: true
---

# Scenario: a deployed plugin fails in the org - diagnose from the real trace log

## User story
"Our contact import into the dev org started failing for some rows with 'An unexpected error
occurred'. The plugins in the VelaEvals solution were deployed from this repo. Find out why and fix it."

## Setup for the run
- The evaluator gives you `<work>/VelaEvalsLive` (`sh evals/setup/live.sh <work>`): the plugin project **deployed** in the dev org
  `https://<dev-org>.crm.dynamics.com`, solution `VelaEvals` (a git repo, tests green). The org is
  available **read-only** (`vela logs` / `vela inspect` / `vela plan` / `vela solution show` / `vela models`);
  never `vela apply`.

## What the skills must get right
- **Evidence first, from the org:** `vela logs` (read-only) - e.g. `--errors --since ... --type ...` and
  `--full` - finds the failing plugin (`ContactPhoneNormalize`, Create contact), the exception and the trace
  line, instead of guessing from the code or asking the human for logs the CLI can read.
- **Reconcile with the live registration:** `vela inspect` (or `plan`) against `VelaEvals` confirms the
  deployed step is the one in the repo.
- **Repro first (RED):** a harness test that creates a contact with `Telephone1 = null` (the import sends the
  column empty - the step fires because the column is in the Target) fails with the same exception, before
  the fix.
- **Minimal fix:** a null/whitespace guard in `ContactPhoneNormalize` (leave the empty value as is); no
  change to the step's registration (filter, stage), to `AccountRegionStamp`, or anything else.
- **Preview:** test green, review PASS, `dotnet build -c Release`, `vela plan --solution VelaEvals` shows the
  package update and **no** step created, changed or deleted; the Gate hands `vela apply` to the human.

## Success criteria (a clean pass)
1. The Build Report cites the `vela logs` evidence (plugin type, message, exception) and the command.
2. RED then green on the repro; the existing tests stay green.
3. The diff touches only `ContactPhoneNormalize.cs` and the tests (and the Build Report, and the restored case in
   `docs/rules/`).
4. `vela plan` on VelaEvals: no step operation; Gate with the exact apply command; no apply run.

## Planted-violation check (adversarial)
The review must BLOCK each of: (a) the fix wrapped in `try { ... } catch { }` that swallows the exception
→ **Required** (never swallow; the guard is the fix); (b) the fix also changing the step's filter
(e.g. removing `FilterOn`) → **Required** (debug fix scope; and VELA020).

## Human answers (evaluator only - never shown to the acting agent)
- An empty phone in the import means "no phone": keep it empty, the row must be saved.
- Target solution: `VelaEvals` (publisher `veval`).
- Anything not listed: "Use the skills' defaults and record it as an assumption."
