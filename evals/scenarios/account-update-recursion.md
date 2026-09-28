---
scenario: account-update-recursion
skills_exercised: [vela-plan-review, vela-scaffold, vela-plugin-authoring, vela-test-harness, vela-code-review]
entity: account
message: Update
gotchas_exercised: [stage-choice, recursion, filtering-attributes, typed-request-target]
org_required: false
---

# Scenario: normalise a column on update without re-triggering yourself

## User story
"Whenever an Account's Description is changed, normalise it: trim leading/trailing whitespace and
collapse repeated spaces into one."

## Why this scenario exists
The obvious implementation is a trap: a PostOperation Update step filtered on `description` that
writes the normalised value back with `ctx.UserService.Update`. That write is itself an Update of
`description`, so the step fires again - and again - until Vela's depth guard throws ("Plugin
execution stopped to prevent recursion") and the user's save fails. The skills must lead the agent to
**Sync PreOperation, editing `ctx.Request.Target`**, which changes the value inside the same write.

## Setup for the run
- Fresh scratch dir. `vela` and `dotnet` on PATH. No Dataverse org: skip `vela models` / `vela plan`,
  recording the exact commands. Never run `vela apply`.
- `account.description` is not in the scaffold's demo model: follow `vela-plugin-authoring`'s no-org
  stand-in rule.

## Success criteria (a clean pass)
1. The Canvas's Approach records **Sync PreOperation** with the reason (same-record column; no extra
   write, nothing re-triggered) and the recursion risk as a Safeguard.
2. The step is `OnUpdate().PreOperation().Sync().FilterOn(e => e.Description)` and the handler sets the
   normalised value on `ctx.Request.Target`. No `ctx.UserService.Update` of the account; no
   `ctx.Depth` early return.
3. Test-first, RED then green, acceptance cases:
   - `"  Hello   world  "` → `"Hello world"` on the target;
   - an already-normal description is left as is;
   - `null` / empty description → left as is (no exception);
   - no extra write reached the in-memory service (`crm.GetAll("account")` empty).
4. Build green, no VELA00x in authored code; `vela-code-review` PASS.

## Planted-violation check (adversarial)
Confirm the review would flag each of:
(a) PostOperation + `ctx.UserService.Update` of the same account → **Critical** (self-trigger: the
    written column is in the step's `FilterOn`);
(b) the same write-back "fixed" with `if (ctx.Depth > 1) return;` → **Critical** (it still writes and
    fires twice; the Depth check hides the design problem and skips legitimate nested calls);
(c) a mutable field caching the last description on the plugin class → **Required** (VELA011).
