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
  a test that passes whatever the code does - e.g. a "does not fire" case run with `Execute`). A
  declared acceptance clause that no test can falsify (e.g. "exactly one write" while the test only counts
  rows) is **Required**: add the assertion, or drop the clause from the Canvas.
- **Canvas consistency:** the Canvas agrees with itself (DoD vs acceptance cases, status) and with the
  Run trace (the commands it names were the ones run) - Nit, or Required if a decision is contradicted.
- **Unconfirmed solution / publisher prefix** (a flagged assumption): not a code finding - it must be
  listed as an open question that blocks the apply gate; Required if it is not.
- **Debug fix scope:** a fix for a reported fault (`vela-debug-plugin`) whose diff touches anything
  beyond the cause and its repro tests (another step's registration, description, filter) - **Required**:
  split it out as a follow-up.
- **Drift from the Canvas** - behaviour, a write, or a decision the Canvas does not record - is
  **Required** (fix the Canvas first, then the code); an unplanned write to the org is **Critical**.
  When a finding is both drift and "will misbehave on a live org", the higher one wins: **Critical**.
- **Target edits that are lost:** editing `ctx.Request.Target` (or the bulk `ctx.Request.Targets`) in a **PostOperation or Async** step
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

Analyzer intent (VELA0xx) plus these recurring Dataverse smells (see `dataverse-gotchas.md`). Items
marked **[analyzer: VELAxxx]** are enforced by the build (Vela.Plugins 0.34.0): if the build output
the dispatcher pasted is clean, they hold - don't re-litigate them, but a suppressed or ignored
diagnostic (`#pragma warning disable VELA...`, `<NoWarn>`) is itself **Required**.

- **Registration:** Create/Update step has a `FilterOn(...)` [analyzer: VELA020] and it names the
  right attribute - on Update **and Create** (a Create filter on a column a create may omit silently skips
  those creates: **Required** unless the Canvas records it); a message with a typed trigger registered via `On<TRequest>()`
  [analyzer: VELA023]; an Associate/Disassociate step **without `ForRelationship(...)`** - **Required**
  (it runs for every association in the org), **Critical** if the handler writes; an Associate handler
  that assumes the Target is the plugin's table without checking `ctx.Request.Target.LogicalName` -
  **Required**; bulk: the same logic on both Update and UpdateMultiple - **Required**; a per-record
  write inside a bulk handler - **Required**, **Critical** if it re-triggers the step (see Recursion).
- **Images:** any image the handler reads is actually registered for that message/stage with the
  needed attributes [analyzer: VELA017 for an uncaptured image; an uncaptured column is a compile error
  on the generated `<Handler>Context`] - still check reads through `GetPreImage<T>()` / aliases, which
  the build does not see.
- **Custom API** (severities): a Function called by Power Automate/flows - **Critical** (the
  Dataverse connector only calls Actions, and the kind can't be changed once created); a unique name
  without the target solution's publisher prefix - **Required** (nothing local checks it; `apply
  --solution` rejects it); the rest below - **Required**. A Function has no side effects; invalid input
  throws `InvalidPluginExecutionException` (not an error code in an output); on the typed form every
  request/response property the Canvas declares is mapped in `.Request(...)` / `.Response(...)` (an
  unmapped one is silently not registered). Parameter names are plain identifiers - a dotted name, or a
  Function without a response property, is rejected when the definition is built (harness / `vela
  plan`), so a green suite proves them; in a diff, either is **Required** (it cannot reach the org - the
  definition build fails first), not Critical.
- **Models:** typed model properties, not magic-string attribute names; models generated by
  `vela models`, never hand-edited - a hand-added or hand-edited property in `Models/Generated` is
  **Required** (regenerate it); no committed `*.generated.cs` (**Required**). `target.Contains(e => e.X)`
  (typed) tells "not sent" from "cleared" on an Update target - prefer it to a logical-name string.
- **Service:** writes go through `ctx.Service` (the step's user - the default) / `ctx.SystemService`
  (SYSTEM) / `ctx.AsUser(id)`; there is no `ctx.OrganizationService` and no `ctx.UserService` (both
  fail to compile). `ctx.SystemService` (bypasses record-level security) used without a reason in the
  Canvas - **Required**.
- **Performance / safety:** no `new ColumnSet(true)` in real queries [analyzer: VELA013]; no unbounded
  RetrieveMultiple; a Sync step does no slow or unreliable external I/O; no parallel work
  [analyzer: VELA024] and no file I/O [analyzer: VELA019].
- **Registration legality** (`registration-rules.md`): no post-image on Delete, no pre-image on
  Create, Async only at PostOperation (these don't compile); Create/Update has a `FilterOn`
  [analyzer: VELA020]; no step on SetState [analyzer: VELA022].
- **Async step that edits the Target:** `ctx.Request.Target` written in an Async handler - **Critical**
  (lost, see Axis 1) [analyzer: VELA018 warning - a warning is still a gate failure; since Vela.Plugins 0.35 it also
  catches writes through a local alias or a helper - verified].
- **Execution order:** rank-sharing with Microsoft/managed steps is NOT a finding (normal, harmless).
  Only flag missing/ambiguous ordering among *our own* steps on the same table+message+stage.
- **SOLID / DRY** (duplicated logic - across plugins or between the steps of one plugin - is
  **Required**): every handler (`OnExecute`, `Handle<Message>`) is thin (SRP) with real logic in a service where it earns it; no
  logic duplicated across plugins or between the steps of one plugin (a shared constant with the rule
  copied into each handler is still duplication); an existing service/plugin reused rather than re-implemented; no
  service extracted for a trivial one-liner.
- **Stage:** a PostOperation step that `Update`s its own primary record where a PreOperation edit of
  `ctx.Request.Target` would do - **Required** (extra write + re-trigger risk), unless the Canvas
  records why the committed state is needed.
- **Recursion:** a write that re-triggers the same step (its filtering attributes include what it
  writes, e.g. a PostOperation `Update` of its own record) - **Critical**, **even when a `ctx.Depth`
  check or `.SkipWhenDepthAbove(n)` stops it early**: it still writes twice and fires twice (verified in
  the harness for `SkipWhenDepthAbove(1)`). A `ctx.Depth` early return or a `SkipWhenDepthAbove` is not a
  guard; on its own (no self-trigger) it is **Required** without a reason in the Canvas (it also skips
  legitimate nested calls). With both present, raise **one** finding: the self-triggering write,
  Critical - the depth line is part of it, not a second finding.
- **Runtime** (`dataverse-gotchas.md`): no mutable fields on the plugin class (**Required**)
  [analyzer: VELA011]; errors thrown as `InvalidPluginExecutionException` [analyzer: VELA012], none
  swallowed; a Sync step does no slow or
  external work (2-minute sandbox limit) and no external side effect before a step that may still
  fail; no `ctx.Depth` early return / `SkipWhenDepthAbove` without a reason in the Canvas (see Recursion
  for severities).
- **Secrets:** none in code or unsecure configuration (`WithUnsecureConfig`) - the step declares
  `.WithSecureConfigFrom("Name")` (value given at deploy time) or uses a secret store. A secret in code
  or unsecure configuration is **Critical**.
- **Outbound calls:** a raw IP address or plain HTTP - **Critical** (the sandbox blocks it: every call
  fails on the org); an outbound call from a **Sync** step without a reason in the Canvas - **Critical**
  (the save waits on, and fails with, the other system, and the external side effect is not rolled back
  with the transaction); no explicit timeout - **Required** (the 2-minute sandbox cutoff is the only
  bound). Code in a ConsoleApp or demo code from
  `vela init --samples`, or outbound code outside the Integrations project (`vela init --integrations`),
  in a real project - **Required**.
- **Correctness:** null/whitespace guards where the spec implies them; no swallowed exceptions. A
  PreOperation edit that writes a column only when its value actually changes (writing an unchanged
  value adds it to the save and can fire other steps) - Nit unless the Canvas requires otherwise.
- **Reused plugin whose name no longer fits** (e.g. `AccountDefaultDescription` now also uppercases the
  number): a Nit - renaming the class re-registers the plugin type; record the decision in the Canvas.

## Output

A findings list, most severe first, each: `severity - file:line - what - why - suggested fix`.
End with a verdict: **PASS** (no Critical/Required) or **BLOCK** (list the blockers). On PASS, also list
the Canvas decisions you checked, one line each (Sync/Async + stage, reuse-vs-new, service-or-helper,
filter) - a PASS with no findings must still show the spec axis was actually reviewed. Record the
list in the Build Report.
