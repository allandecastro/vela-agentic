# Code-review checklist (two axes + severities)

Used by `vela-code-review`. Review the change diff (`git diff <base>...HEAD`, or the fallback in that
skill) on two independent
axes so neither masks the other. Assign every finding a severity; **Critical/Required block the
apply gate.**

## Severities

- **Critical** - will fail or misbehave on a live org, or risks data loss / security. Blocks.
- **Required** - a real defect or a violated repo standard; fix before the gate. Blocks.
- **Nit** - optional polish / preference. Does not block.

## Axis 1 - Spec fidelity (against the Vela Canvas)

Check the diff against the **Vela Canvas** (Requirements/DoD, acceptance cases, and the Approach/
Structure decisions):

- Every declared acceptance case is actually implemented and has a passing test. (An isolated
  reviewer has no shell: the dispatcher includes the test runner's summary lines with the diff.)
- **RED evidence:** the Run trace shows the tests failing before the implementation for the right
  reason, then passing; every acceptance case has a test that would fail if the behaviour broke (not
  a test that passes whatever the code does - e.g. a "does not fire" case run with `Execute`).
- **Canvas consistency:** the Canvas agrees with itself (DoD vs acceptance cases, status) and with the
  Run trace (the commands it names were the ones run) - Nit, or Required if a decision is contradicted.
- **Unconfirmed solution / publisher prefix** (a flagged assumption): not a code finding - it must be
  listed as an open question that blocks the apply gate; Required if it is not.
- **Drift from the Canvas** - behaviour, a write, or a decision the Canvas does not record - is
  **Required** (fix the Canvas first, then the code); an unplanned write to the org is **Critical**.
  When a finding is both drift and "will misbehave on a live org", the higher one wins: **Critical**.
- **Target edits that are lost:** editing `ctx.Request.Target` in a **PostOperation or Async** step
  changes nothing that is saved - **Critical** (the behaviour silently does not happen).
- Message / stage / mode match the Canvas (Create vs Update vs *Multiple; Pre vs Post). For a Custom
  API: global/bound, Action/Function, parameters and error cases match the Canvas.
- The Canvas's **Approach** decisions were honoured: **Sync vs Async** is appropriate for the
  business need (Async only for non-blocking/eventual work, never for validation); **reuse vs new**
  was respected (`vela add step` on an existing plugin where it fit; no hand-created class).
- Edge cases from the spec (empty / null / whitespace / boundary) are handled, not just the happy path.
- No scope creep: nothing implemented that the Canvas did not ask for. If the diff diverged from the
  Canvas, the Canvas should have been updated first (fix-spec-first) - flag if not.

## Axis 2 - Standards + Dataverse smell baseline

Analyzer intent (VELA00x) plus these recurring Dataverse smells (see `dataverse-gotchas.md`):

- **Registration:** Create/Update step has a `FilterOn(...)` (mandatory) and it names the right
  attribute for Update; an Associate/Disassociate step bound to a table (all Vela 0.29.3 Associate
  steps are) - **Critical** (never fires; see gotchas); bulk: the same logic on both Update and
  UpdateMultiple, or a per-record write inside a bulk handler - **Required**. Associate/Disassociate matched by **message**, not by primary entity.
- **Images:** any image the handler reads is actually registered for that message/stage with the
  needed attributes.
- **Custom API** (severities): a dot in a parameter/unique name - **Critical** (uncallable on a real
  org; nothing local rejects it); a Function called by Power Automate/flows - **Critical** (the
  Dataverse connector only calls Actions, and the kind can't be changed once created); the rest below -
  **Required**. No parameter/unique name contains a dot; the unique name
  carries the target solution's publisher prefix; a Function has no side effects; invalid input throws
  `InvalidPluginExecutionException` (not an error code in an output); on the typed form every
  request/response property is mapped in `.Request(...)` / `.Response(...)`.
- **Models:** typed model properties, not magic-string attribute names; models regenerated, not
  hand-edited; no committed `*.generated.cs` (**Required**). **Exception - not a finding:** a property
  added to `Models/Generated` with a `// STAND-IN for vela-models (no org)` comment, when the run had
  no org (`vela-plugin-authoring` step 2). Record it as a Nit ("regenerate with `vela models` before
  apply") so it is not forgotten. `target.Contains("<column>")` to tell "not sent" from "cleared" on
  an Update target is acceptable (no typed equivalent).
- **Service:** writes go through `ctx.UserService` / `ctx.SystemService` (there is no
  `ctx.OrganizationService`); elevation used only when justified.
- **Performance / safety:** no `new ColumnSet(true)` in real queries (VELA013); no unbounded
  RetrieveMultiple; a Sync step does no slow or unreliable external I/O.
- **Registration legality** (`registration-rules.md`): no post-image on Delete, no pre-image on
  Create, Async only at PostOperation; Create/Update has a `FilterOn`.
- **Execution order:** rank-sharing with Microsoft/managed steps is NOT a finding (normal, harmless).
  Only flag missing/ambiguous ordering among *our own* steps on the same table+message+stage.
- **SOLID / DRY** (duplicated logic - across plugins or between the steps of one plugin - is
  **Required**): every handler (`OnExecute`, `Handle<Message>`) is thin (SRP) with real logic in a service where it earns it; no
  logic duplicated across plugins; an existing service/plugin reused rather than re-implemented; no
  service extracted for a trivial one-liner.
- **Stage:** a PostOperation step that `Update`s its own primary record where a PreOperation edit of
  `ctx.Request.Target` would do - **Required** (extra write + re-trigger risk), unless the Canvas
  records why the committed state is needed.
- **Recursion:** a write that re-triggers the same step (its filtering attributes include what it
  writes, e.g. a PostOperation `Update` of its own record) - **Critical**, **even when a `ctx.Depth`
  check stops it early**: it still writes twice and fires twice. A `ctx.Depth` early return is not a
  guard; on its own (no self-trigger) it is **Required** (it also skips legitimate nested calls).
- **Runtime** (`dataverse-gotchas.md`): no mutable fields on the plugin class (VELA011 - **Required**); errors
  thrown as `InvalidPluginExecutionException` (VELA012), none swallowed; a Sync step does no slow or
  external work (2-minute sandbox limit) and no external side effect before a step that may still
  fail; no `ctx.Depth` early return without a reason in the Canvas (see Recursion for severities).
- **Secrets:** none in code or unsecure configuration - secure configuration or a secret store.
  A secret in code is **Critical**.
- **Correctness:** null/whitespace guards where the spec implies them; no swallowed exceptions. A
  PreOperation edit that writes a column only when its value actually changes (writing an unchanged
  value adds it to the save and can fire other steps) - Nit unless the Canvas requires otherwise.
- **Reused plugin whose name no longer fits** (e.g. `AccountDefaultDescription` now also uppercases the
  number): a Nit - renaming the class re-registers the plugin type; record the decision in the Canvas.

## Output

A findings list, most severe first, each: `severity - file:line - what - why - suggested fix`.
End with a verdict: **PASS** (no Critical/Required) or **BLOCK** (list the blockers). Record the
list in the Build Report.
