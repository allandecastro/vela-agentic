---
_description: "The vela-apply skill: packages, signs if needed, previews with vela plan and stops at the apply gate"
---

# vela-apply

This page describes `vela-apply`, the skill that packages a reviewed plugin, previews its deployment and stops at
the apply gate. It is for the human who reads the Build Report and decides whether to deploy.

## When it triggers

When the suite is green, the analyzers are clean and the review passed: to preview the package always, and to
deploy it only when a human authorizes it. Also after an authorized apply, to confirm the org matches the package.

## What it does

1. **Package:** clears `artifacts/`, runs `dotnet build -c Release` (not `dotnet pack`), checks the package holds
   the plugin assembly, and records its path and SHA-256. The package is built last, after the tests.
2. **Sign** when the org requires signed packages, before the preview. Without a certificate it records "unsigned".
   See [Sign the plugin package](../../guides/signing.md).
3. **Confirm the solution** with `vela solution show <uniquename> --json` (read-only): its publisher prefix must
   match `PROJECT.md`.
4. **Preview** with `vela plan` on the exact packages the Canvas ships. Every operation must be one the Canvas
   expects; every diagnostic line is read.
5. **Write the Gate** section of the Build Report: the apply command, what it will change, the rollback and its
   limits, and a check to run on the org when the harness cannot prove the story.
6. **Stop.**

```bash
vela plan -p artifacts/zava_Zava.Plugins.1.0.0.nupkg --solution ZavaSales --url https://<org>.crm.dynamics.com \
  --detailed-exitcode --out .vela-runs/<slug>/plan.json
```

For what `plan` compares and its exit codes, see [Plan and apply](../../guides/plan-apply.md).

## After an authorized apply

It runs the apply with the same package (same hash), the same solution, secure configuration and connection as the
preview, reports from the result's `executed` block, then runs `vela inspect` to confirm no difference remains.

## What it never does

- Run `vela apply` without an explicit go-ahead for that run. "Ship it" or a merged pull request is not one.
- Set `VELA_APPLY_APPROVED` or route around the [deploy guard](../hooks.md).
- Preview with a placeholder secure-configuration value. A value it does not hold stays an open item.
- Reuse a preview after any code change: tests, review, package and preview run again.
- Report success on a partial apply (exit `7`) or one that did not converge (exit `5`).

Source: [`skills/vela-apply/SKILL.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/skills/vela-apply/SKILL.md).
