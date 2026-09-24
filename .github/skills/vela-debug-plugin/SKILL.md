---
name: vela-debug-plugin
description: Use when a Vela plugin does not fire, fires on the wrong message/entity, throws, or produces unexpected results — by reconciling registered steps and images against the code and reproducing the fault in the harness.
---

# Debug a Vela plugin

Diagnose a plugin that misbehaves by reconciling what the code intends to register against
what is actually registered, and by reproducing the fault in the harness.

## When to use

- A step does not trigger, triggers on the wrong message/entity, throws, or returns wrong
  results.

## Process

Announce: `Using vela-debug-plugin to <purpose>`.

1. State the symptom precisely (which message/entity/stage, expected vs observed).
2. Read the code's intended registration (the step/plugin definition and filtering attributes).
3. Compare with the live org using `vela inspect` (and `vela plan` to see pending diffs).
4. Check the usual suspects from `references/dataverse-gotchas.md`:
   - Associate/Disassociate matched by primary entity only (won't fire),
   - filtering attribute excludes the changed attribute,
   - a required image is missing or lacks the attribute,
   - custom API param name with a dot (uncallable).
5. **Reproduce in the harness** (`vela-test-harness`): write a failing test that captures the
   fault. This turns a live symptom into a local, repeatable red.
6. Form a single most-likely hypothesis with evidence, then fix and prove green.

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
