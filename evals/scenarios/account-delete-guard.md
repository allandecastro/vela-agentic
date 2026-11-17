---
scenario: account-delete-guard
skills_exercised: [vela-plan-review, vela-scaffold, vela-plugin-authoring, vela-plugin-testing, vela-code-review, vela-apply]
entity: account
message: Delete
gotchas_exercised: [delete-target-is-reference, prevalidation-to-block, async-cannot-block, typed-query, ipe-errors]
org_required: true
---

# Scenario: block deleting an account that still has active contacts

## User story
"People must not be able to delete an account that still has active contacts. Tell them why, so they
can deal with the contacts first."

## Setup for the run
- The evaluator provides the `ZavaSales` project (`<work>/ZavaSales`, a git repo, `account` / `contact`
  models generated, one existing Create plugin). The dev org `https://<dev-org>.crm.dynamics.com` is
  available **read-only** (`vela models` / `vela solution show` / `vela plan` / `vela inspect` / `vela logs`);
  never `vela apply`.

## What the skills must get right
- **Registration:** a new plugin on **Delete** of `account`, **Sync PreValidation** (blocks before the main
  operation and its cascades; Async cannot block) - scaffolded with `vela add plugin ... --message Delete`.
- **Target:** `ctx.Request.Target` is an `EntityReference` - the check reads the contacts, not the target's
  columns.
- **Query:** active contacts of the account via a **typed query** (`Query.For<Contact>()` ... `Where(c =>
  c.ParentCustomerId, ...)` + `StateCode == Active`), with `ctx.Service`, reading as few columns as needed -
  no logical-name strings.
- **Error:** `InvalidPluginExecutionException` with a message the user can act on (how many active
  contacts; deal with them first).
- **Tests:** RED then green through `PluginPipeline` (`p.Service.Delete(...)` throws with an active contact;
  succeeds with none, or only inactive ones; a contact of another account does not count).

- **Localized message** (rubric addition 2026-10-18): the error is raised with `ctx.BusinessError("KEY", ...)`
  from a message source registered in `ConfigureServices` (the project's convention, asked at design), with the
  English and French templates; a test asserts the message.

## Success criteria (a clean pass)
1. Canvas: Delete, PreValidation, Sync with the reason; the error message; what "active" means.
2. Typed query, no `QueryExpression` / logical-name strings in plugin code.
3. RED then green; review PASS; `vela plan --solution ZavaSales` shows the new Delete step; no apply.

## Planted-violation check (adversarial)
The review must BLOCK each of: (a) the step registered **Async** (plant it as `.PostOperation().Async()` - PreValidation + Async does not
compile) → **Critical** (it cannot block the delete); (b) the query without the `StateCode` condition (inactive contacts also block) → **Required**
(spec drift); (c) the query rewritten as a `QueryExpression` with logical-name strings → **Required**.

## Human answers (evaluator only - never shown to the acting agent)
- "Active contacts" = contacts whose parent customer is the account and whose status is Active.
- The message should say how many active contacts and to deactivate or move them first.
- If asked about messages / languages: "our users work in English and French; messages are localized. For now
  the project keeps them in an in-code dictionary (1033 English, 1036 French)."
- If asked which security roles the users hold: "Salesperson" (a standard role of the dev org).
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
