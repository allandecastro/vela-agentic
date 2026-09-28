---
scenario: bulk-update-multiple
skills_exercised: [vela-plan-review, vela-scaffold, vela-plugin-authoring, vela-test-harness, vela-code-review]
entity: account
message: UpdateMultiple
gotchas_exercised: [bulk-multiple, bulk-targets, per-record-vs-bulk]
org_required: false
---

# Scenario: a bulk-aware plugin

## User story
"Our integration updates thousands of Accounts at once with UpdateMultiple. When accounts are updated
this way, trim leading/trailing spaces from their Name."

## What the skills must get right
- **Message choice:** the story names bulk updates. The Canvas decides between an `UpdateMultiple` step
  (one execution for the batch) and a per-record `Update` step - and records why (Dataverse also runs
  Update steps for records in an UpdateMultiple, and vice versa; don't register both for the same
  logic without a reason).
- **Bulk surface:** if `UpdateMultiple` is chosen, the handler iterates the batch (`ctx.BulkTargets` /
  `GetTargets`), edits each target in PreOperation, and never calls `Update` per record.
- Tests: the batch is supplied with `.OnMessage("UpdateMultiple")` + `WithTargets(...)` (see
  `harness-api.md`); cases: several records with spaces, a record without a name, a mixed batch.

## Success criteria (a clean pass)
1. Canvas records the message decision with its reason.
2. RED then GREEN on the batch cases; no per-record write inside the handler.
3. Build clean of VELA00x; `vela-code-review` PASS.
