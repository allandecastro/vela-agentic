---
scenario: account-second-behaviour
skills_exercised: [vela-plan-review, vela-scaffold, vela-plugin-authoring, vela-test-harness, vela-code-review]
entity: account
message: Update
gotchas_exercised: [reuse-vs-new, dry-service, sync-vs-async, filtering-attributes]
org_required: false
depends_on: account-default-description   # a Create plugin already defaults Description
---

# Scenario: second behaviour on a table that already has a plugin

## Setup for the run
- The evaluator provides the reviewed `account-default-description` baseline, which already has the
  `AccountDefaultDescription` Create plugin (`sh evals/setup/baseline.sh <work>` → `<work>/ZavaSales`,
  a git repo). The dev org `https://dyn-premium-dev.crm.dynamics.com` is available **read-only** (`vela models` / `vela solution show` / `vela plan` / `vela inspect` / `vela logs`); never `vela apply`.

## User story
"When an Account is updated and its Description is cleared (set to empty), re-apply the same
default 'Created via Vela plugin'."

## The decisions this scenario tests (must appear, resolved, in the Vela Canvas)
- **Reuse vs new:** the Account already has a plugin → prefer `vela add step` (Update) on it, or a
  new plugin only if genuinely separate. **Not** a hand-created class.
- **DRY:** the defaulting logic already exists (Create). It must be **defined once** and shared by both
  paths, **not** copy-pasted. Both steps live in the same plugin (reuse via `vela add step`), so a shared
  private helper + a single constant is the right shape; a `vela add service` is equally acceptable, and
  required only if the logic were shared across plugins. (Rubric corrected 2026-09-30: it used to demand
  a service, which contradicts the pack's "no service for a one-liner" rule - flagged by the grader.)
- **Sync vs Async / stage:** the default must be on the committed record → **Sync PreOperation**,
  set on `ctx.Request.Target` (Async would be wrong; PostOperation + Update would re-trigger the step).
- **Filtering:** the Update step's `FilterOn(e => e.Description)` gates it to Description changes.

## Success criteria (a clean pass)
1. The Canvas's Approach/Structure record the reuse (`add step`) and how the rule is shared (helper or service),
   and Sync with a reason.
2. No duplicated defaulting logic; one definition (helper + constant, or a service) is used by both the
   Create and Update paths, and the Canvas records the decision with a correct reason.
3. Test-first: RED acceptance tests (Description cleared → re-defaulted; changed to a real value →
   untouched) before implementation, green after.
4. `vela-code-review` PASS: the SOLID/DRY axis confirms no duplication; the spec axis confirms the
   reuse decision was honoured.

## Planted-violation check (adversarial)
Confirm the review would **BLOCK** each of: (a) the defaulting logic copy-pasted into a second
class (DRY - Required); (b) a hand-created plugin class instead of `vela add step` (Required);
(c) the step registered **Async** (**Critical**: the Target edit is lost - the default is never saved;
also a spec/Approach mismatch). Plant it as `.PostOperation().Async()`: PreOperation + Async does not
compile (Vela.Plugins 0.35 has no `Async()` after `PreOperation()`). (Rubric note 2026-10-17.)

## Human answers (evaluator only - never shown to the acting agent)
- "Cleared" = null, "" or whitespace-only; reuse the Create default.
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
