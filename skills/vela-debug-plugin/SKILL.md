---
name: vela-debug-plugin
description: Use when a Vela plugin does not fire, fires on the wrong message or entity, throws, or produces unexpected results.
compatibility: "vela CLI >= 0.27.3 (Vela.Plugins >= 0.40.0); dotnet SDK."
---

# Debug a Vela plugin

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Reconcile what the code intends to register with what is registered, and reproduce the fault in the
harness. **No red repro, no fix.**

## When to use

- A step does not trigger, triggers on the wrong message/entity, throws, or returns wrong results.

## Evidence you can get

- Intended registration: read `RegisterPluginSteps()` / `RegisterCustomApi()`.
- Behaviour: a harness test (`references/harness-api.md`).
- With a connection (all read-only): `vela inspect` (live vs package), `vela plan` (pending diff),
  `vela logs` (trace + exception; `--jobs` for failed system jobs). Without one: **a human**.

No raw Web API calls around the CLI. Flags: `vela <cmd> --help`, `references/cli-surface.md`.

## Process

Announce: `Using vela-debug-plugin to <purpose>`. Loop: reproduce → minimize → hypothesize →
instrument → fix → regression-test - not trial and error.

1. **State the symptom:** message/entity/stage/mode from the code; from the human only what they did,
   expected vs observed (one question if missing).
2. **Runtime evidence when the fault is on a live org.**
   - **With a connection**, read it yourself: `vela logs --type <PluginType> --since <window> --full --json
     <connection>` (narrow with `--errors`, then `--correlation <guid>` for one cascade). A failed
     **async** step is a failed system job: `--jobs`. Exit `6` → the human path.
   - **Without a connection**, ask the human for the Plug-in Trace Log row(s) - **every** such request,
     even an optional "to confirm" one, says where and what: Power Apps → *Advanced settings* →
     *Settings* → *Plug-in Trace Log* (or the Plugin Registration Tool); type name, message, primary
     entity, stage/mode, **depth**, correlation id, **exception details**, and the **message block**
     (your `ctx.Trace(...)` output).
   - Rows exist only with tracing on (*System Settings* → *Customization*); if off, ask the human to
     enable it and reproduce - don't change it yourself.
   Depth above 1 or "prevent recursion" → recursion (`references/dataverse-gotchas.md`). **No row at
   all** (tracing on) = the step never fired: suspect the registration (filter, message, entity,
   relationship scope), not the handler.
3. **Reproduce locally (mandatory):** a failing harness test (`vela-test-harness`) capturing the symptom.
   **"Does not fire", filters, cascades and recursion: use `PluginPipeline`** - `PluginContext...Execute`
   ignores `FilterOn`. No org is the normal path: reproduce from the description. An unexpectedly green
   repro is not exercising the registration - switch to the pipeline. Write the light Canvas (symptom,
   hypothesis, repro cases, the one-line change) **before** the fix.
4. **Minimize** to the smallest failing input; add only the repro and directly related regressions.
5. **Hypothesize** from registration + evidence against `references/dataverse-gotchas.md`: a filter
   excluding the changed attribute; a missing or incomplete image (`ctx.PreImage` null); wrong stage
   (PostOperation target edit lost; PreOperation write-back recursion); Associate/Disassociate scoped by
   `.ForRelationship(...)` to another relationship (`ExecutionLog`: `HandlerInvoked == false` +
   `SkipReason`); a dotted Custom API param name; mutable plugin state (VELA011); sandbox limits.
   Compare with `vela inspect` when connected, else record the command. `<uniquename>` comes from the
   Canvas / Build Report or the human - never guessed from the repo name.
6. **Instrument** if still unclear: `ctx.Trace(...)`, reproduce, read `pipeline.Trace.Output` (or
   `vela logs --full`). A step that never fires writes no trace - read `pipeline.ExecutionLog`.
7. **Fix only the most-likely cause.** The diff is the cause plus the repro tests - no incidental edit
   elsewhere (each is a change the human must re-verify); the rest is a follow-up.
8. **Regression-test.** Red now green and kept; full suite green; `vela inspect` **and** `vela plan` (or
   the recorded commands) confirm the registration matches intent. Faulty org unreachable → record the
   exact `vela inspect` / `vela plan` / `vela logs` commands against **that** org and aim the apply gate
   at it: an org you can reach does not ship the fix where the fault is.

When the harness and the org disagree, read Vela's limitations page (`references/plugin-authoring-api.md`,
*Platform services*) before suspecting the code: the harness is a faithful-but-partial model.

## Rationalizations (excuse → rebuttal)

- "I'll just tweak and re-apply to see." → Guessing against a live org is slow and side-effecting.
- "It must be a platform issue." → Reconcile registration and images before blaming Dataverse.
- "I can't reproduce without the org." → The harness can. The trace confirms; it does not start.
- "I'll read the trace log through the Web API." → `vela logs`, or the human.
- "Obvious fix, the test can come later." → A fix without a red test is a guess.
- "I'll tidy this other registration while I'm in here." → A debug fix is minimal; record a follow-up.

## Red flags

- A code change before a failing repro test exists, or a fix diff beyond the cause and its tests.
- Mutating the org while diagnosing.
- Reporting the intended state instead of the observed one.
- `if (ctx.Depth > 1) return;` to make a recursion symptom disappear.
- Guessing the solution unique name instead of reading the Canvas or asking.
- Asking for "the logs" without where/which fields - or asking at all when `vela logs` can read them.

## Verification

- A harness test reproduces the fault (red) and passes after the fix (green); the suite is green.
- The explanation cites evidence, not "it seems".
- `vela inspect`/`vela plan` confirm the registration matches intent, or the exact commands are
  recorded for the human.
