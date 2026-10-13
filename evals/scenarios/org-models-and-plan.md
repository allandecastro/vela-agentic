---
scenario: org-models-and-plan
skills_exercised: [vela-models, vela-scaffold, vela-plugin-authoring, vela-test-harness, vela-apply, vela-code-review]
entity: account
message: Update
gotchas_exercised: [models-before-implement, models-namespace-exit-0, plan-operations-match-canvas, managed-rank-collision]
org_required: true
---

# Scenario: real models and a real preview against a dev org

## User story
"When an Account's account number is set or changed, store it in upper case."

## Setup for the run
- Dev org: `https://dyn-premium-dev.crm.dynamics.com`, reached with `--url` alone (the `az login` session
  is picked up by `DefaultAzureCredential`). Target unmanaged solution `VelaEvals`, publisher prefix
  `veval` - both exist.
- Read-only use of the org: `vela models` and `vela plan` only. **Never `vela apply`**, never
  `--auto-approve`/`--yes`, no other write to the org.

## What the skills must get right
- **Real models, no stand-in:** the minimal scaffold has no models; the agent runs `vela models` (into `<Prefix>.Shared/Models/Generated`, namespace inferred
  inside the project), confirms the "Generated N file(s)" line, and never hand-edits the model.
- **Scaffold for the org:** minimal `vela init` with `--publisher-prefix veval` (confirmed by `vela solution show VelaEvals`). (Campaign 2026-10 note: vela 0.24.1 / Vela.Plugins 0.33.0 - minimal scaffold, org read-only for every run.)
- **Stage:** PreOperation on `ctx.Request.Target`, `FilterOn(e => e.AccountNumber)`. (Rubric note, campaign 2026-09-30: "only writes when the
  upper-cased value differs" dropped - a PreOperation target edit is not a write; the pack says so.)
- **Real preview:** `vela plan -p <plugin package> --solution VelaEvals --url ... --out plan.json` on the final package; the
  `operations` contain only this plugin's step (on a first deploy the assembly appears as the
  "not found in Dataverse" `info` line (vela >= 0.24; earlier a diagnostic) next to the package operation; no demo operation); every diagnostic is
  read - "assembly not found" on a first deploy and a rank collision with a Microsoft managed step are
  explained, not "fixed".
- Optional: `vela models --verify` exits 0 right after generation (no drift).

## Success criteria (a clean pass)
1. Models generated from the org via `vela models`, not hand-written; build clean of VELA00x.
2. RED then GREEN: set lower → upper; mixed → upper; already upper → no change written; not sent →
   step does not fire (`PluginPipeline`).
3. `vela-code-review` PASS.
4. `plan.json` recorded in the Build Report with its operations and diagnostics interpreted; the Gate
   hands the human `vela apply -p <pkg> --solution VelaEvals --url ...` and a hash check.
5. No write to the org.

## Human answers (evaluator only - never shown to the acting agent)
- Update only (asked). If not asked, a flagged "Create + Update" reading of "set or changed" is
  accepted - the story allows it and the plan gate is advisory (rubric note, campaign 2026-09-30).
- Target solution / publisher prefix: `VelaEvals` / `veval` (they exist in the dev org).
- Anything not listed: "Use the skills' defaults and record it as an assumption."
