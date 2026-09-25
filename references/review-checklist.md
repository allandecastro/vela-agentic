# Code-review checklist (two axes + severities)

Used by `vela-code-review`. Review the change diff (`git diff <base>...HEAD`) on two independent
axes so neither masks the other. Assign every finding a severity; **Critical/Required block the
apply gate.**

## Severities

- **Critical** — will fail or misbehave on a live org, or risks data loss / security. Blocks.
- **Required** — a real defect or a violated repo standard; fix before the gate. Blocks.
- **Nit** — optional polish / preference. Does not block.

## Axis 1 — Spec fidelity (against the Vela Canvas)

Check the diff against the **Vela Canvas** (Requirements/DoD, acceptance cases, and the Approach/
Structure decisions):

- Every declared acceptance case is actually implemented and has a passing test.
- Message / stage / mode match the Canvas (Create vs Update vs *Multiple; Pre vs Post).
- The Canvas's **Approach** decisions were honoured: **Sync vs Async** is appropriate for the
  business need (Async only for non-blocking/eventual work, never for validation); **reuse vs new**
  was respected (`vela add step` on an existing plugin where it fit; no hand-created class).
- Edge cases from the spec (empty / null / whitespace / boundary) are handled, not just the happy path.
- No scope creep: nothing implemented that the Canvas did not ask for. If the diff diverged from the
  Canvas, the Canvas should have been updated first (fix-spec-first) — flag if not.

## Axis 2 — Standards + Dataverse smell baseline

Analyzer intent (VELA00x) plus these recurring Dataverse smells (see `dataverse-gotchas.md`):

- **Registration:** Create/Update step has a `FilterOn(...)` (mandatory) and it names the right
  attribute for Update; Associate/Disassociate matched by **message**, not by primary entity.
- **Images:** any image the handler reads is actually registered for that message/stage with the
  needed attributes.
- **Custom API:** no parameter/unique name contains a dot (uncallable on a real org).
- **Models:** typed model properties, not magic-string attribute names; models regenerated, not
  hand-edited; no committed `*.generated.cs`.
- **Service:** writes go through `ctx.UserService` / `ctx.SystemService` (there is no
  `ctx.OrganizationService`); elevation used only when justified.
- **Performance / safety:** no `new ColumnSet(true)` in real queries (VELA013); no unbounded
  RetrieveMultiple; a Sync step does no slow or unreliable external I/O.
- **Registration legality** (`registration-rules.md`): no post-image on Delete, no pre-image on
  Create, Async only at PostOperation; Create/Update has a `FilterOn`.
- **Execution order:** rank-sharing with Microsoft/managed steps is NOT a finding (normal, harmless).
  Only flag missing/ambiguous ordering among *our own* steps on the same table+message+stage.
- **SOLID / DRY:** `OnExecute` is thin (SRP) with real logic in a service where it earns it; no
  logic duplicated across plugins; an existing service/plugin reused rather than re-implemented; no
  service extracted for a trivial one-liner.
- **Correctness:** null/whitespace guards where the spec implies them; no swallowed exceptions.

## Output

A findings list, most severe first, each: `severity — file:line — what — why — suggested fix`.
End with a verdict: **PASS** (no Critical/Required) or **BLOCK** (list the blockers). Record the
list in the Build Report.
