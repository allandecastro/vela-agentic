---
scenario: account-erp-outbound
skills_exercised: [vela-plan-review, vela-scaffold, vela-models, vela-plugin-authoring, vela-plugin-testing, vela-code-review, vela-apply]
entity: account
message: Create
gotchas_exercised: [integrations-project, outbound-sandbox, secure-config, sync-vs-async, external-side-effect-not-rolled-back]
org_required: true
---

# Scenario: notify an external ERP when an account is created (outbound call)

## User story
"When an Account is created, tell our ERP about it: POST the account's id and name as JSON to
`https://erp.zava-demo.com/api/accounts`. The ERP authenticates calls with an API key sent in the
`X-Api-Key` header. If the ERP is down, people must still be able to save accounts."

## Setup for the run
- The evaluator gives you an **empty** work dir: there is no project yet. `vela` and `dotnet` on PATH.
  The dev org `https://dyn-premium-dev.crm.dynamics.com` is available **read-only** (`vela models` /
  `vela solution show` / `vela plan` / `vela inspect` / `vela logs`); never `vela apply`.
- The ERP is not reachable from this machine; nothing in the run may call it.

## What the skills must get right
- **Project:** a new solution scaffolded with `vela init ... --integrations` (never `--samples`); the
  plugin lives in the **Integrations** project (`vela add plugin ... --project src/<P>.Integrations/...`),
  not in `<P>.Plugins`. Models for `account` generated with `vela models` before the plugin.
- **Stage / mode:** **Async PostOperation Create** - the account id exists only after the create, a down
  ERP must not block the save (an Async failure does not undo the save; a Sync one would), and an
  external side effect is never rolled back, so it must not run inside the transaction.
- **Secret:** the API key is declared with `.WithSecureConfigFrom("<Name>")` and read through
  `SecureConfig`; it is never in code, unsecure config, a test, a settings file or the repo. The agent
  does not invent a value; the Build Report tells the human how to supply it at deploy time
  (`--secure-config <Name>=@file` or `VELA_SECURE_CONFIG_<Name>`, not a value on the command line).
- **Sandbox:** HTTPS to the DNS name; an explicit timeout well under 2 minutes; a non-success status or a
  timeout surfaces as `InvalidPluginExecutionException` (the async job fails visibly) - never swallowed.
- **Design:** the HTTP call sits in a service (outbound I/O is worth isolating) and the suite makes **no
  real network call** - the call is tested against a fake (an injected sender or `HttpMessageHandler`).
  Since Vela.Testing 0.36.0 the supported way is `PluginPipeline.WithService<T>(fake)`, so the success path
  runs through the pipeline; a test-only constructor or seam added to the plugin is a review finding (rubric
  note 2026-10-17: before 0.36 the framework had no way, and naming that gap was the expected move).
- **Preview:** `dotnet build -c Release` builds **two** packages (`<P>.Plugins` and `<P>.Integrations`);
  `vela plan --solution ZavaSales` covers every package the Canvas ships. The `<P>.Plugins` package is empty
  in this story: previewing it too, or leaving it out of both the preview and the apply command with that
  decision recorded in the Canvas, are both correct (rubric note 2026-10-17: `vela-apply` previews "the
  packages the Canvas ships"; leaving the empty one out avoids creating an empty package in the org). Without the key,
  plan reports the missing secure configuration as a diagnostic - recorded as an open item at the gate,
  not "fixed" by passing an invented value.

- **Environment-specific URL** (rubric addition 2026-10-18): the ERP URL differs per environment, so it is read
  from an environment variable (`ctx.GetEnvironmentVariable`), not a constant in code - asked or decided at design
  and recorded in the Canvas; tests supply the value.

## Success criteria (a clean pass)
1. The Canvas records Async PostOperation Create with the reason (save must not depend on the ERP; side
   effect outside the transaction), the Integrations project, the secure-config name, the timeout.
2. Test-first, RED then green: the request carries id + name as JSON and the `X-Api-Key` header from
   secure config; a non-success response / timeout throws `InvalidPluginExecutionException`; the step is
   registered Async PostOperation Create (pipeline or definition test). No test reaches the network.
3. Build clean of VELA00x; `vela-code-review` PASS.
4. Both packages built; `vela plan` on every package the Canvas ships (see Preview), read-only; the Gate names
   how the human supplies the key.

## Planted-violation check (adversarial)
The review must BLOCK each of: (a) the API key as a string constant in the service → **Critical**
(secret in code/repo); (b) the step switched to **Sync** → **Critical** (a down ERP blocks the save; the
external call cannot be rolled back); (c) the `HttpClient` timeout removed → **Required** (sandbox 2-minute
cutoff, no explicit bound); (d) the URL changed to a raw IP (`https://20.50.1.10/api/accounts`) →
**Critical** (the sandbox blocks raw IP addresses).

## Human answers (evaluator only - never shown to the acting agent)
- Target solution / publisher prefix: `ZavaSales` / `zava`. Namespace prefix: `Zava`.
- The API key: "Ops holds it and supplies it at deploy time. I can't give it to you, and it must never be
  in the code or the repo."
- Payload: `{"id": "<account guid>", "name": "<account name>"}`; the ERP answers 2xx on success.
- Retries: "no retry - a failed call should show as a failed system job; ops replays it."
- If asked about the URL or environments: "each environment has its own ERP (dev, test, prod) - the base URL
  is in the environment variable `zava_ErpBaseUrl` (https://erp.zava-demo.com in dev)."
- Anything not listed: "Use the skills' defaults and record it as an assumption."
