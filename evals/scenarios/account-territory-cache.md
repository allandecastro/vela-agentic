---
scenario: account-territory-cache
skills_exercised: [vela-plan-review, vela-grill, vela-models, vela-plugin-authoring, vela-test-harness, vela-code-review]
entity: account
message: Create
gotchas_exercised: [cache-reference-data, cache-not-user-data, typed-queries, filtering-attributes]
org_required: true
depends_on: account-default-description
---

# Scenario: reference data read on every save - cache it, safely

## User story
"When an account is created or its country changes, set its sales territory: the territory whose name is the
account's country."

## Setup for the run
- The evaluator provides the `ZavaSales` project (`sh evals/setup/baseline.sh <work>` → `<work>/ZavaSales`, a
  git repo, `account` / `contact` models generated, one existing Create plugin, its Build Report and the rules
  registry). The dev org `https://dyn-premium-dev.crm.dynamics.com` is available **read-only** (`vela models` /
  `vela solution show` / `vela plan` / `vela inspect` / `vela logs`); never `vela apply`.

## What the skills must get right
- **Platform services - cache:** territories are reference data read on every account save and changed rarely →
  `IPluginCacheService` (`GetOrCreate` with an explicit TTL recorded in the Canvas, a feature-prefixed key).
- **Never cache user-filtered data:** the cached territory list is read in a way that is the same for every user
  (`ctx.SystemService`, with the Canvas reason: shared reference data, only an id is written), not through
  `ctx.Service` under a shared key.
- **Steps:** Sync PreOperation on Create and Update of account, `FilterOn` the country column, the territory set
  on `ctx.Request.Target` (no write-back); a new plugin (separate concern from the description default).
- **Models:** `territory` models generated with `vela models`; typed query (`Query.For<Territory>`).
- **Tests:** RED first; cases include: matching territory set, no matching territory → left empty, country
  cleared → territory cleared, and a cache case (a second execution does not re-query, or a changed territory
  shows after the TTL / an invalidation).

## Success criteria (a clean pass)
1. `IPluginCacheService.GetOrCreate` with an explicit TTL; the key is feature-prefixed; the Canvas records the TTL
   and why the data is safe to cache.
2. The cached query does not run as the calling user under a shared key.
3. Steps as above; tests RED then green (incl. a cache case); review PASS; plan run; no apply.
4. Rules registry: the new rule in English Given/When/Then, tests carry its case ids; spec-check passes.

## Planted-violation check (adversarial)
The review must BLOCK: (a) the territory list read through `ctx.Service` and cached under a key shared by all
users → **Required**; (b) no matching territory throws an error instead of leaving the territory empty →
**Required** (spec mismatch).

## Human answers (evaluator only - never shown to the acting agent)
- Territories are reference data maintained by admins a few times a year; every user can see them.
- If asked about freshness / delay: "a territory change may take up to an hour to show on new saves - fine."
- No territory matches the country → leave the territory empty; country cleared → clear the territory.
- Match the name exactly (case-insensitive).
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
