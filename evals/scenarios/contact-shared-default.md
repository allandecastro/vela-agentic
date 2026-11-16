---
scenario: contact-shared-default
skills_exercised: [vela-plan-review, vela-scaffold, vela-plugin-authoring, vela-plugin-testing, vela-code-review]
entity: contact
message: Create
gotchas_exercised: [service-trigger-second-consumer, dry-service, regression-test-not-bent, reuse-vs-new]
org_required: true
depends_on: account-default-description   # the Account Create plugin already holds the default inline
---

# Scenario: a second consumer turns inline logic into a service

## User story
"Contacts created without a description should get the same default text as accounts."

## Setup for the run
- The evaluator provides the `ZavaSales` project (`sh evals/setup/baseline.sh <work>` → `<work>/ZavaSales`, a
  git repo, `account` / `contact` models generated, the `AccountDefaultDescription` Create plugin, its tests, its Build Report and the rules registry). The dev org
  `https://<dev-org>.crm.dynamics.com` is available **read-only** (`vela models` / `vela solution show`
  / `vela plan` / `vela inspect` / `vela logs`); never `vela apply`.

## What the skills must get right
- **Service trigger - a second consumer:** the defaulting rule now has two consumers in two plugins (account,
  contact). The Canvas names the trigger and records `service: new:<Name>` (`vela add service`); the rule
  (text + blank check) lives once, in the service, used by both plugins.
- **A move, not a behaviour change:** `AccountDefaultDescription` is refactored to call the service; its
  ACC-001 tests stay unchanged and green (spec-check passes).
- **Contact behaviour:** a new Contact Create step (Sync PreOperation, set on the Target), not a step on the
  account plugin; its rule (e.g. CON-001) in `docs/rules/contact.md`, cross-referenced from ACC-001's table if
  relevant; new tests carry `[Trait("Case", "CON-001/Cn")]`, RED first.

## Success criteria (a clean pass)
1. The default text appears once in `src/`, inside a service used by both plugins; the Canvas records the
   service decision with the second-consumer reason.
2. ACC-001 tests unchanged and green; new contact tests RED then green; spec-check passes.
3. Review PASS; `vela plan --solution ZavaSales` run; no apply.

## Planted-violation check (adversarial)
The review must BLOCK: (a) the default text and blank check copied into the contact plugin (no service) →
**Required**; (b) an ACC-001 test edited during the refactor → **Critical**.

## Human answers (evaluator only - never shown to the acting agent)
- Same text ("Created via Vela plugin"); blank = null, "" or whitespace-only.
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
