---
name: vela-debug-plugin
description: Use when a Vela plugin does not fire, fires on the wrong message or entity, throws, or produces unexpected results.
---

# Debug a Vela plugin

Diagnose a plugin that misbehaves by reconciling what the code intends to register against
what is actually registered, and by reproducing the fault in the harness.

## When to use

- A step does not trigger, triggers on the wrong message/entity, throws, or returns wrong
  results.

## Process

Announce: `Using vela-debug-plugin to <purpose>`. Follow a disciplined loop — reproduce →
minimize → hypothesize → instrument → fix → regression-test — not trial and error.

1. **Reproduce.** State the symptom precisely (message/entity/stage, expected vs observed), then
   write a failing harness test (`vela-test-harness`) that captures it — a live symptom becomes
   a local, repeatable red.
2. **Minimize.** Strip the case to the smallest input that still fails.
3. **Hypothesize.** Read the code's intended registration (step/plugin, filtering attributes)
   and compare with the live org via `vela inspect` (and `vela plan` for pending diffs). Check
   the usual suspects in `references/dataverse-gotchas.md`:
   - Associate/Disassociate matched by primary entity only (won't fire),
   - filtering attribute excludes the changed attribute,
   - a required image missing or lacking the attribute,
   - custom API param name with a dot (uncallable).
4. **Instrument** if the cause is still unclear (`ctx.Trace(...)`, inspect images/target).
5. **Fix** the single most-likely cause with evidence.
6. **Regression-test.** The red test now passes; `vela inspect`/`vela plan` confirm the
   registration matches intent.

## Rationalizations (excuse → rebuttal)

- "I'll just tweak the code and re-apply to see." → Reproduce in the harness first; guessing
  against a live org is slow and side-effecting.
- "It must be a platform issue." → Reconcile registration and images before blaming Dataverse.

## Red flags

- Mutating the org while diagnosing (investigation is read-only by default).
- Reporting the intended state instead of the observed state.

## Verification

- A harness test reproduces the fault (red), and passes after the fix (green).
- `vela inspect`/`vela plan` confirm the registration now matches intent.
