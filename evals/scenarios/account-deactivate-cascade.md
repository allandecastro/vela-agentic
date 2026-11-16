---
scenario: account-deactivate-cascade
skills_exercised: [vela-plan-review, vela-scaffold, vela-plugin-authoring, vela-plugin-testing, vela-code-review, vela-apply]
entity: account
message: Update
gotchas_exercised: [setstate-never-fires-vela022, statecode-transition, transaction-all-or-nothing, typed-query, per-record-writes]
org_required: true
---

# Scenario: deactivate the contacts when their account is deactivated

## User story
"When an account is deactivated, its active contacts must be deactivated too."

## Setup for the run
- The evaluator provides the `ZavaSales` project (`<work>/ZavaSales`, a git repo, `account` / `contact`
  models generated, one existing Create plugin). The dev org `https://dyn-premium-dev.crm.dynamics.com` is
  available **read-only** (`vela models` / `vela solution show` / `vela plan` / `vela inspect` / `vela logs`);
  never `vela apply`.

## What the skills must get right
- **Message:** an **Update** step on `account` filtered on `statecode` - **not** SetState (VELA022: a
  SetState step never fires; deactivation from the app and `SetStateRequest` both fire Update).
- **Transition:** act only when the new state is Inactive (`ctx.Request.Target.StateCode == Inactive`) -
  reactivating an account does nothing to its contacts.
- **Stage / mode:** **Sync PostOperation** (the human wants it immediate and all-or-nothing: a failure
  leaves the account active) - the account is saved, the contact writes are in the same transaction.
- **Query and writes:** active contacts of the account by a **typed query** (`Query.For<Contact>()`),
  then each set to Inactive (`StateCode` + `StatusCode`) with `ctx.Service`; no `SystemService` without a
  reason in the Canvas.
- **Tests:** RED then green through `PluginPipeline`: Update `StateCode = Inactive` deactivates the active
  contacts; reactivation does nothing; another account's contacts are untouched. (`SetStateRequest` is
  deprecated - a test with it is optional, not required.)

## Success criteria (a clean pass)
1. Canvas: Update + `statecode` filter (and why not SetState), Sync PostOperation and why, the transition.
2. Typed query; no logical-name strings in plugin code.
3. RED then green; review PASS; `vela plan --solution ZavaSales` shows the new Update step; no apply.

## Planted-violation check (adversarial)
The review must BLOCK each of: (a) the transition check removed (reactivation also deactivates the
contacts) → **Critical** (wrong data on a live org); (b) the contact writes switched to `ctx.SystemService`
without a reason in the Canvas → **Required**; (c) the step moved to **Async** → **Required** (spec drift:
the human asked for immediate, all-or-nothing).

## Human answers (evaluator only - never shown to the acting agent)
- It must be immediate: right after deactivating the account, its contacts show as inactive; if deactivating a
  contact fails, the account must stay active.
- Reactivating an account does **not** reactivate its contacts.
- Only contacts whose parent customer is the account; inactive status reason = "Inactive".
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
