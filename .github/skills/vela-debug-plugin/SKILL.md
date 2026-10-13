---
name: vela-debug-plugin
description: Use when a Vela plugin does not fire, fires on the wrong message or entity, throws, or produces unexpected results.
compatibility: "vela CLI >= 0.24.1 (Vela.Plugins >= 0.33.0); dotnet SDK."
---

# Debug a Vela plugin

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Diagnose a plugin that misbehaves by reconciling what the code intends to register against
what is actually registered, and by reproducing the fault in the harness. **No red repro, no fix.**

## When to use

- A step does not trigger, triggers on the wrong message/entity, throws, or returns wrong
  results.

## Evidence you can get

| Evidence | How | Needs |
| --- | --- | --- |
| Intended registration | read `RegisterPluginSteps()` / `RegisterCustomApi()` | nothing |
| Live registration vs package | `vela inspect -p <pkg> --solution <uniquename> <connection>` (read-only) | an org connection |
| Pending registration diff | `vela plan -p <pkg> --solution <uniquename> <connection>` (read-only) | an org connection |
| Runtime trace + exception | `vela logs ... <connection>` (read-only: Plug-in Trace Log, `--jobs` for failed system jobs) | an org connection; else **a human** |
| Behaviour | a harness test (`references/harness-api.md`) | nothing |

The CLI is the contract: do not query the org around it (no raw Web API calls). With a connection, read
the trace yourself with `vela logs`; without one, ask the human for it (step 2).

## Process

Announce: `Using vela-debug-plugin to <purpose>`. Follow a disciplined loop - reproduce →
minimize → hypothesize → instrument → fix → regression-test - not trial and error.

1. **State the symptom precisely:** message, entity, stage and mode come from the code
   (`RegisterPluginSteps()`); from the human only what they did, expected vs observed. Missing a
   piece? Ask for it in one question.
2. **Get the runtime evidence when the fault is on a live org.**
   - **With a connection** (flags in `references/cli-surface.md`), read it yourself - read-only:
     `vela logs --type <PluginType> --since <window> --full --json <connection>` (narrow with `--errors`,
     `--message <m>`, `--entity <table>`; then `--correlation <guid>` for the whole cascade of one
     operation). An **async** step that failed is a failed system job: `vela logs --jobs --since <window>
     --json <connection>`. Exit `6` = connection failure: fall back to the human path below.
   - **Without a connection**, ask the human for the Plug-in Trace Log row(s) of the failing operation -
     **every** such request, even an optional "to confirm" one in a report or open question, carries
     the where / what to paste: where: Power Apps → *Advanced settings* → *Settings* → *Plug-in Trace Log*
     (or the Plugin Registration Tool); what: type name, message, primary entity, stage/mode, **depth**,
     correlation id, the **exception details**, and the **message block** (your `ctx.Trace(...)` output).
   - Either way, trace rows exist only when tracing is on (*System Settings* → *Customization* → *Enable
     logging to plug-in trace log*: *Exception* or *All*). It is an org setting: if it is off, ask the human
     to enable it and reproduce once - don't change it yourself.
   A Depth above 1 or a "prevent recursion" message points at recursion
   (`references/dataverse-gotchas.md`). **No row at all** for the operation (with tracing on) is
   evidence too: the step never fired - suspect the registration (filtering attribute, message,
   entity, relationship scope), not the handler code.
3. **Reproduce locally (mandatory):** write a failing harness test (`vela-test-harness`,
   `references/harness-api.md`) that captures the symptom - a live symptom becomes a local,
   repeatable red. **"Does not fire", filtering attributes, cascades and recursion: use
   `PluginPipeline`** - `PluginContext...Execute` runs the handler regardless of `FilterOn`, so it
   cannot reproduce a step that never fires. **No org at all?** Reproduce from the symptom
   description alone; that is the normal path, not a degraded one. If the repro is unexpectedly
   green, the test is not exercising the registration yet - switch to the pipeline before concluding.
   Write the (light) Canvas **before** the fix - symptom, cause hypothesis, repro cases, the one-line
   change - with the repro tests; it grows into the Build Report.
4. **Minimize.** Strip the case to the smallest input that still fails. A debug run adds the repro
   plus any directly related regression case - not the full coverage set of a new build.
5. **Hypothesize** from the registration and the evidence, against the usual suspects in
   `references/dataverse-gotchas.md`:
   - filtering attribute excludes the changed attribute (step never fires),
   - a required image missing or lacking the attribute (`ctx.PreImage` is null / incomplete),
   - wrong stage (PostOperation edit of the target has no effect; PreOperation write-back recursion),
   - Associate/Disassociate scoped by `.ForRelationship(...)` to another relationship (the handler is
     skipped; the trace says "relationship outside the step's ForRelationship scope"),
   - custom API param name with a dot (uncallable), mutable plugin state (VELA011),
   - sandbox limits (file system, raw IP, 2-minute timeout).
   Compare intent with the live registration via `vela inspect -p <pkg> --solution <uniquename>
   <connection>` when a connection is available (flags in `references/cli-surface.md`); otherwise record
   the exact command for the human.
6. **Instrument** if the cause is still unclear: add `ctx.Trace(...)` lines for the values you need,
   reproduce, read the message block (`pipeline.Trace.Output` locally, `vela logs --full` on the org). A
   step that never fires writes no trace - read `pipeline.ExecutionLog` instead (which steps ran, with
   message, stage, mode, depth). Remove noise
   afterwards; keep traces that help operations.
7. **Fix** the single most-likely cause with evidence - and **only** that cause. The diff is the cause
   plus the repro tests: no incidental edit to another step's registration, description, filter,
   image or code "while you are there" (each is a second change `vela plan` will show and the human
   must re-verify). Anything else you notice goes in the report as a follow-up, not in this fix.
8. **Regression-test.** The red test now passes and stays in the suite; the full suite is green;
   `vela inspect`/`vela plan` (or the recorded commands) confirm the registration matches intent.

## Rationalizations (excuse → rebuttal)

- "I'll just tweak the code and re-apply to see." → Reproduce in the harness first; guessing
  against a live org is slow and side-effecting.
- "It must be a platform issue." → Reconcile registration and images before blaming Dataverse.
- "I can't reproduce without the org." → The harness can: the registration, images and target
  are all yours to set. Reproduce from the description; read the trace to confirm (`vela logs`, or the
  human with the where/what of step 2), not to start.
- "I'll read the trace log through the Web API myself." → Not through the CLI contract. Use `vela logs`;
  without a connection, ask the human for the row and name the fields you need.
- "Obvious fix, the test can come later." → No red repro, no fix. A fix without a red test is a guess.
- "I'll tidy this other registration while I'm in here." → A debug fix is minimal. Record it as a
  follow-up; an extra change widens what the human must re-verify and masks what fixed the fault.

## Red flags

- A code change before a failing repro test exists.
- A fix diff that touches anything beyond the cause and its repro tests.
- Mutating the org while diagnosing (investigation is read-only by default).
- Reporting the intended state instead of the observed state.
- Guarding with `if (ctx.Depth > 1) return;` to make a recursion symptom disappear.
- Asking the human for "the logs" without saying where they are and which fields to paste - or asking at
  all when a connection is available and `vela logs` can read them.

## Verification

- A harness test reproduces the fault (red), and passes after the fix (green); the suite is green.
- The explanation cites the evidence (`vela logs` output or trace fields, `vela inspect` output, or the
  repro test) - not "it seems".
- `vela inspect`/`vela plan` confirm the registration now matches intent, or the exact commands are
  recorded for the human.
