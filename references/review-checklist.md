# Code-review checklist (two axes + severities)

Used by `vela-code-review`. Review the diff (`git diff <base>...HEAD`, or that skill's fallback) on two
independent axes so neither masks the other. Every finding gets a severity; **Critical/Required block the
apply gate.**

## Severities

- **Critical** - will fail or misbehave on a live org, or risks data loss / security. Blocks.
- **Required** - a real defect or a violated repo standard. Blocks.
- **Nit** - optional polish. Does not block.

When a finding is both drift and "misbehaves on a live org", the higher wins: **Critical**.

## Axis 1 - Spec fidelity (against the Vela Canvas)

- Every acceptance case is implemented and has a passing test (an isolated reviewer has no shell: the
  dispatcher pastes the runner summary with the diff).
- **RED evidence:** the Run trace shows tests failing for the right reason, then passing; each case has a
  test that would fail if the behaviour broke (not one that passes regardless, e.g. a "does not fire"
  case run with `Execute`). An acceptance clause no test can falsify (e.g. "exactly one write" while the
  test only counts rows) - **Required**: add the assertion or drop the clause.
- **Canvas consistency** with itself (DoD vs cases, status) and the Run trace - **Nit**, **Required** if a
  decision is contradicted.
- **Rules registry:** a rule added / changed / retired by the diff but not reflected in `docs/rules/<table>.md` -
  **Required**; behaviour that contradicts an active rule without a human decision recorded (and the old rule
  retired) - **Required**; a rule deleted from the file instead of marked `retired` (history lost) - **Required**.
- **Tests vs functional cases:** an existing (regression) test modified or deleted while its rule is not
  `change`/`retire` in the Canvas - **Critical**; a modified test that no longer matches its case's
  Given/When/Then (data, action, assertion) - **Required**; a test without a `Case` id - **Required**;
  `docs/rules/` edited after the frozen-spec commit and not listed in the Canvas `amendments:` (trace lines aside) - **Critical** (`spec-check.py` reports these).
- **Unconfirmed solution / publisher prefix:** must be an open question blocking the apply gate -
  **Required** if not listed.
- **Debug fix scope** (`vela-debug-plugin`): a diff touching more than the cause and its repro tests -
  **Required** (split out as a follow-up).
- **Drift** (behaviour, write or decision the Canvas does not record) - **Required** (Canvas first, then
  code); an unplanned write to the org - **Critical**.
- **Lost Target edits:** editing `ctx.Request.Target` / `Targets` in a **PostOperation or Async** step
  saves nothing - **Critical**.
- Message / stage / mode match the Canvas (Create vs Update vs *Multiple; Pre vs Post); for a Custom API:
  global/bound, Action/Function, parameters, error cases.
- **Approach honoured:** Sync vs Async fits (Async only for non-blocking work, never validation);
  reuse vs new respected (`vela add step` where it fit; no hand-created class).
- Edge cases from the spec (empty / null / whitespace / boundary) handled, not just the happy path.
- No scope creep: behaviour that traces to neither the story nor a recorded human answer - **Required**
  (**Critical** when it drives security or disclosure); a divergence must have updated the Canvas first.

## Axis 2 - Standards + Dataverse smell baseline

Analyzer intent plus the smells in `dataverse-gotchas.md`. **[VELAxxx]** items are enforced by the build:
if the pasted build output is clean they hold - don't re-litigate; a suppressed diagnostic
(`#pragma warning disable VELA...`, `<NoWarn>`) is itself **Required**. A warning is still a gate failure.

- **Registration:** Create/Update `FilterOn` [VELA020] names the right attribute, on Update **and
  Create** (a Create filter on a column a create may omit skips those creates - **Required** unless the
  Canvas records it); `On<TRequest>()` for a typed trigger [VELA023]; Associate/Disassociate without
  `ForRelationship(...)` - **Required**, **Critical** if the handler writes; an Associate handler that
  assumes the Target's table without checking `ctx.Request.Target.LogicalName` - **Required**; the same
  logic on both Update and UpdateMultiple - **Required**; a per-record write in a bulk handler -
  **Required**, **Critical** if it re-triggers the step.
- **Images:** every image read is registered with the needed columns [VELA017; uncaptured columns don't
  compile on `<Handler>Context`] - check `GetPreImage<T>()` / alias reads by hand.
- **Custom API:** a Function called by Power Automate/flows - **Critical** (the connector only calls
  Actions; the kind can't change after creation); unique name without the publisher prefix - **Required**
  (`apply --solution` rejects it); the rest **Required**: a Function has no side effects; invalid input
  throws `InvalidPluginExecutionException` (not an error output); every Canvas request/response property
  is mapped in `.Request(...)` / `.Response(...)` (unmapped = silently not registered). A dotted parameter
  name or a Function without a response property fails at definition build (harness / `vela plan`) -
  **Required**, not Critical.
- **Models:** typed properties, not magic strings; a hand-added/edited property in `Models/Generated` -
  **Required** (regenerate); a committed `*.generated.cs` - **Required**. Prefer typed
  `target.Contains(e => e.X)` (tells "not sent" from "cleared"). Logical-name strings
  (`QueryExpression`, `GetAttributeValue<T>("x")`) where `Query.For<T>()` / `ToEntity<T>()` would do -
  **Nit** in tests, **Required** in plugin code.
- **Service:** writes via `ctx.Service` (the step's user, default) / `ctx.SystemService` (SYSTEM) /
  `ctx.AsUser(id)`. `ctx.SystemService` without a Canvas reason - **Required**; data read as SYSTEM that
  reaches the user (in an error message or output) - **Required**, even with a reason.
- **Performance / safety:** no `ColumnSet(true)` [VELA013], no unbounded RetrieveMultiple (Vela's typed `Query...ToList` pages through all rows), no slow or
  unreliable external I/O in a Sync step, no parallel work [VELA024], no file I/O [VELA019].
- **Registration legality** (`registration-rules.md`): no post-image on Delete, no pre-image
  on Create, Async only at PostOperation (these don't compile); no step on SetState [VELA022].
- **Async step editing the Target** - **Critical** (lost) [VELA018].
- **Execution order:** rank shared with managed steps is NOT a finding; flag only missing/ambiguous order
  among our own steps on one table+message+stage.
- **Plugin classes and naming:** a new plugin class on a table that already has one, with no Canvas reason (own
  config, other package, Custom API) - **Required**; `OnExecute` in a class with several steps, or a shared file
  (messages, registrar) under another name than the convention - **Nit**.
- **Documentation:** a plugin/service type without a `<summary>` naming its rule, a handler without its rule/why
  line, comments narrating the code - **Nit**.
- **SOLID / DRY:** duplicated logic (across plugins or between one plugin's steps; a shared constant with
  the rule copied into each handler still counts) - **Required**. Handlers stay thin, real logic in a
  service where it earns it, existing services/plugins reused, no service for a one-liner. A service
  trigger met (second consumer, data access plus decisions, an oversized handler) with logic left inline
  - **Required** for a second consumer, **Nit** otherwise. The same query or rule definition in two places, a
  block repeated per column, a service registered twice or outside `ProjectServices` - **Required**.
- **Stage:** a PostOperation `Update` of its own primary record where a PreOperation Target edit would do
  - **Required**, unless the Canvas records why.
- **Recursion:** a write that re-triggers its own step - **Critical**, even when a `ctx.Depth` check or
  `.SkipWhenDepthAbove(n)` stops it (it still writes and fires twice). A depth early return / skip on its
  own (no self-trigger) - **Required** without a Canvas reason. With both, raise **one** Critical finding.
- **Runtime:** mutable plugin fields - **Required** [VELA011]; `InvalidPluginExecutionException`
  [VELA012], nothing swallowed; no slow/external work in a Sync step and no external side effect before a
  step that may still fail.
- **Platform services** (the Canvas records the choices): a user-facing message hard-coded when the project
  localizes, or missing one of the project's languages - **Required**; a message source assumed, not asked -
  an open item at the Gate; message texts or a source defined inside a plugin instead of the assembly's shared place
  (`IServiceRegistrar`) - **Required**; an environment-specific value (URL, threshold, id) as a constant - **Required**;
  data read as the calling user put in the shared cache - **Critical** (it leaks across users); behaviour that
  depends on rights with no `WithSecurity` test - **Required**.
- **Secrets:** a secret in code or unsecure config (`WithUnsecureConfig`) - **Critical**; use
  `.WithSecureConfigFrom("Name")` or a secret store. A secure-config value the behaviour depends on must
  be proven by a test that supplies it (`WithSecureConfig(name, value)`) and asserts it reaches the call;
  only a "missing key" test - **Required** (a hard-coded key would keep the suite green).
- **Outbound calls:** raw IP [VELA025] or plain HTTP - **Critical**; an outbound call from a **Sync** step
  without a Canvas reason - **Critical**; no explicit timeout [VELA026] -
  **Required**; ConsoleApp or `--samples` demo code, or outbound code outside the Integrations project,
  in a real project - **Required**.
- **Correctness:** null/whitespace guards the spec implies; no swallowed exceptions. A PreOperation edit
  that writes an unchanged value - **Nit** unless the Canvas requires otherwise.
- **Reused plugin whose name no longer fits** - **Nit** (renaming re-registers the type); record it in the
  Canvas.

## Output

Findings most severe first: `severity - file:line - what - why - suggested fix`. Verdict **PASS** (no
Critical/Required) or **BLOCK** (list blockers). On PASS also list the Canvas decisions checked, one line
each (Sync/Async + stage, reuse-vs-new, service-or-helper, filter). Record the list in the Build Report.
