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
  a git repo). No org; never `vela apply`.

## User story
"When an Account is updated and its Description is cleared (set to empty), re-apply the same
default 'Created via Vela plugin'."

## The decisions this scenario tests (must appear, resolved, in the Vela Canvas)
- **Reuse vs new:** the Account already has a plugin → prefer `vela add step` (Update) on it, or a
  new plugin only if genuinely separate. **Not** a hand-created class.
- **DRY / service:** the defaulting logic already exists (Create). It must be **shared** - extract
  a service (`vela add service`) reused by both steps, **not** copy-pasted.
- **Sync vs Async / stage:** the default must be on the committed record → **Sync PreOperation**,
  set on `ctx.Request.Target` (Async would be wrong; PostOperation + Update would re-trigger the step).
- **Filtering:** the Update step's `FilterOn(e => e.Description)` gates it to Description changes.

## Success criteria (a clean pass)
1. The Canvas's Approach/Structure record the reuse (`add step`) and the shared service decision,
   and Sync with a reason.
2. No duplicated defaulting logic; a single service is reused by both the Create and Update paths.
3. Test-first: RED acceptance tests (Description cleared → re-defaulted; changed to a real value →
   untouched) before implementation, green after.
4. `vela-code-review` PASS: the SOLID/DRY axis confirms no duplication; the spec axis confirms the
   reuse decision was honoured.

## Planted-violation check (adversarial)
Confirm the review would **BLOCK** each of: (a) the defaulting logic copy-pasted into a second
class (DRY - Required); (b) a hand-created plugin class instead of `vela add step` (Required);
(c) the step registered **Async** (**Critical**: the Target edit is lost - the default is never saved;
also a spec/Approach mismatch).
