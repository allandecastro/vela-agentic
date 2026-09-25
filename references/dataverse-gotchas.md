# Dataverse & Vela gotchas (battle-tested)

Real failure modes seen in Vela plugins. Skills cite these as Red Flags. Each entry is a
symptom → cause → fix.

## Registration & steps

- **Associate / Disassociate steps not firing.** These messages are not tied to a single
  primary entity; a step matched by primary entity alone silently never runs. Match the
  message regardless of primary entity.
- **Create/Update step never triggers on the change you expect.** A filtering attribute
  excludes the attribute that actually changed. Check the filtering attributes against the
  attribute being written.
- **Create/Update step throws at registration: "must declare at least one filtering attribute".**
  Every Create/Update step requires a `FilterOn(...)`. This throws when the registration is
  materialized (harness `Execute`, `vela plan`/`apply`), NOT at `dotnet build` — so a green build
  is not proof. On Create the filter is ignored at runtime but still mandatory — default it to the
  primary column and never drop it, even when the step should fire on every create. On Update the
  filter actually gates the trigger.
- **Image is empty at runtime.** The image was not registered for that message/stage, or the
  requested attributes were not included. Verify the image registration, not just the code.

## Custom APIs

- **Custom API is uncallable on a real org** despite working locally. Parameter/unique names
  contained a dot. Use dot-free unique names (the CLI self-heals, but verify).

## Deep insert / relationships

- **Grandchild records in a deep insert are dropped or mis-parented.** Multi-level deep
  inserts need each level wired correctly; verify the whole tree, not just the first child.

## Codegen & project layout

- **Compiles locally, missing on CI.** A committed source file was named `*.generated.cs`,
  which is gitignored. Never name a committed file `*.generated.cs`; let the CLI name output.
- **Adding a typed message silently misbehaves.** A modelled plugin message touches several
  files that must stay in sync (including the CLI's known-messages list). Use `vela add`
  rather than hand-wiring; regenerate rather than editing generated output.

## Build / smoke

- **You compiled against a stale framework.** Purge the `vela.plugins` / `vela.testing`
  caches under `~/.nuget` before a smoke build, or you build against an old package.

## Execution order / rank

- **Rank "collisions" with Microsoft / managed steps are normal and harmless.** `vela plan` may
  report that your step shares a rank with other steps on the same message/stage (e.g. MS managed
  plugins like PredictiveScoring, OpportunityScoring). You do **not** control or truly conflict with
  managed steps — **do not bump your rank just to dodge them.**
- What actually matters is deterministic ordering among **your OWN** steps on the same
  table + message + stage. Use `WithExecutionOrder(n)` only to sequence *your* steps relative to
  each other when you register more than one; don't set it reactively to avoid managed steps.

## Analyzers

- **VELA002** — every `RegisterStep()` chain must end with `.Handle(...)`.
- **VELA013** — `new ColumnSet(true)` retrieves every column and is flagged. Prefer an explicit
  `new ColumnSet("attr1", "attr2")`. (The scaffold's own demo tests use `ColumnSet(true)` and
  trip this — cosmetic in generated demo code, but do not copy the pattern into real queries.)

## Verification discipline

- Report the **observed** org/build/test state, never the intended one.
- `models --verify` exits `5` on drift and `plan`/`apply` exit `6` on connection failure —
  treat non-zero exit codes as failures to surface, not to swallow.
