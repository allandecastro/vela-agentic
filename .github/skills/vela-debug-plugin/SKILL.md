---
name: vela-debug-plugin
description: Investigate why a Vela plugin step is not firing or not behaving as expected — matching registered steps, images, and messages against the code. Use when a plugin does not trigger, throws, or produces unexpected results in Dataverse.
---

# Debug a Vela plugin

Help diagnose a Vela plugin that does not fire, throws, or produces unexpected results,
by reconciling the registered steps and images in the org against the project's code.

## Minimum CLI version

`0.15.0` — run `vela --version` and stop if older.

## When to use

- A registered step does not trigger, or triggers on the wrong message/entity.
- A plugin throws or returns unexpected output against a live org.

## Steps

1. `vela --version`, then explore the CLI for read/inspection commands via
   `vela --help` and the relevant `--help` pages.
2. Read the project's step registrations and message definitions first — understand
   what the code *intends* to register.
3. Compare against what is actually registered in the org (use the CLI's read/verify
   capabilities). Look especially for:
   - message/entity mismatches (for example Associate/Disassociate steps that must
     match regardless of primary entity),
   - missing or misconfigured images,
   - filtering attributes that exclude the update you expect to trigger on.
4. Form a single most-likely hypothesis, state the evidence, and propose the concrete
   fix (usually a code change re-applied via the `vela-apply` skill).

## Guardrails

- Do not mutate the org while diagnosing unless the user asks; investigation is
  read-only by default.
- Report the actual observed state, not the intended state.
