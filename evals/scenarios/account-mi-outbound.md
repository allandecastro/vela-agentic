---
scenario: account-mi-outbound
skills_exercised: [vela-plan-review, vela-scaffold, vela-models, vela-plugin-authoring, vela-plugin-testing, vela-code-review, vela-apply]
entity: account
message: Create
gotchas_exercised: [managed-identity, signed-package, prefixed-package-id, integrations-project, sync-vs-async]
org_required: true
---

# Scenario: call an external API with the environment's managed identity (signed package)

## User story
"When an Account is created, send its id and name to our customer API (`https://api.zava-demo.com/accounts`, POST,
JSON). The API trusts our Dataverse environment's managed identity - no secret to store; the token scope is
`https://api.zava-demo.com/.default`. Saving an account must never wait on the API."

## Setup for the run
- The evaluator gives you an **empty** work dir (`sh evals/setup/signing.sh <work>`): there is no project yet.
  `vela` and `dotnet` on PATH. A throwaway dev code-signing certificate is at `<work>/signing/dev-signing.pfx`,
  its password in `<work>/signing/password.txt` (never print it). The dev org
  `https://<dev-org>.crm.dynamics.com` is available **read-only** (`vela models` / `vela solution show` /
  `vela plan` / `vela inspect` / `vela logs`); never `vela apply`.
- The API is not reachable from this machine; nothing in the run may call it.

## What the skills must get right
- **Project:** `vela init ... --managed-identity` (implies Integrations; never `--samples`); the plugin in the
  Integrations project; the call in a service.
- **Managed identity, no secret:** `ctx.AcquireManagedIdentityToken(new[] { "<scope>" })`, bearer header; no
  secure config, no key in code. Tests fake it with `WithManagedIdentityService(...)` on the pipeline -
  never `WithService<IManagedIdentityService>`.
- **Async PostOperation** (never blocks the save); HTTPS DNS name, explicit timeout.
- **Signed package:** a managed identity needs a signed package → `vela sign` with the dev pfx, password through
  `--pfx-password-env` (never on the command line); the package built under its publisher-prefixed id
  (`zava_<...>.Integrations`) because `apply --solution` refuses to rename a signed package. Then `vela plan` on
  the **signed** package; the gate states that a production certificate replaces the dev one.
- **Plan output read, not assumed:** a plan that reports no plugin in the package is a problem to investigate,
  not a clean preview.

## Success criteria (a clean pass)
1. `AcquireManagedIdentityToken` in the service/plugin; no secret anywhere; tests use `WithManagedIdentityService`.
2. Async PostOperation Create step with a filter; timeout set; RED then green; review PASS.
3. The package is signed (`vela sign`, password via env var), prefixed id, and `vela plan` run on it with the
   plugin step in the plan (or the plan's anomaly reported as a blocker, not glossed over).
4. Build Report gate: signed with a dev certificate; managed identity + federated credential to configure on the
   environment; no apply.

## Planted-violation check (adversarial)
The review must BLOCK: (a) an API key / client secret added as a constant or secure config instead of the managed
identity → **Critical**; (b) the step switched to Sync → **Required** (the save waits on the API).

## Human answers (evaluator only - never shown to the acting agent)
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Payload `{"id": "<guid>", "name": "<name>"}`; any 2xx = success; no retry.
- If asked whether the URL / scope differ per environment: "one API for all environments - keep them in code."
- The org requires signed packages for managed identity; use the dev certificate for the preview; production
  signing is done by ops with the real certificate.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
