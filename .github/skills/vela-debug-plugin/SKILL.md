---
name: vela-debug-plugin
description: Use when a Vela plugin does not fire, fires on the wrong message or entity, throws, or produces unexpected results.
compatibility: "vela CLI + dotnet SDK."
license: MIT
metadata:
  version: "0.1.13"
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

0. **Triage - bug or change?** Find the rule in `docs/rules/` the behaviour falls under. The code breaks it →
   a bug: this skill, the rule unchanged. The code follows it and the human wants otherwise → a **change
   request**: stop, the rule changes with the human first (`vela-plan-review`, fix-spec-first) - never bend
   code and tests to the complaint. No rule covers it → ask the human which it is.
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
   all** (tracing on) = the step never fired (unless the failure is older than the trace-log retention, often
   24h: reproduce it, then re-check): suspect the registration (filter, message, entity,
   relationship scope), not the handler.
3. **Reproduce locally (mandatory):** a failing harness test (`vela-plugin-testing`) capturing the symptom.
   **Through `PluginPipeline`**: it runs the registration, so filters, cascades and recursion reproduce. No org
   is the normal path: reproduce from the description. An unexpectedly green repro does not send what the
   user sent (the columns, the message, the table) - match the report.
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
7. **Commit the Canvas** - a small-story Canvas (`using-vela`: front matter + cases; the symptom and hypothesis
   in `decisions:`) with the repro tests, each tagged with the `Case` of the rule it proves. No registry, or no rule
   covering the expected behaviour → write that rule and case in `docs/rules/<table>.md` in this commit (step 0: the
   behaviour the human expects). No edit to `src/` before this commit.
8. **Fix only the most-likely cause**, in its own commit. The diff is the cause - no incidental edit elsewhere
   (each is a change the human must re-verify); the rest is a follow-up. Red now green and kept; full suite green.
9. **Back to the build loop:** load `vela-code-review` and follow it, **then** load `vela-apply` and follow it
   (through the preview) - don't redo their steps from memory. Then the Build Report in the Canvas
   (`docs/features/<slug>/README.md`); stop at the apply gate.
10. **Faulty org unreachable:** the gate also names **that** org with the exact commands to run there, e.g.
   `vela inspect --url <faulty org>`, `vela plan --package <nupkg> --solution <uniquename> --url <faulty org>
   --detailed-exitcode`, `vela logs --type <PluginType> --since 1d --url <faulty org>`.

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

- A code change before a failing repro test exists, or a fix diff beyond the cause and its tests (a repro case added
  to `docs/rules/` is listed in the Canvas `amendments:`).
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
