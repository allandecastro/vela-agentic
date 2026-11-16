---
scenario: account-rule-conflict
skills_exercised: [vela-plan-review, vela-grill, vela-plugin-authoring, vela-plugin-testing, vela-code-review, vela-apply]
entity: account
message: Create
gotchas_exercised: [rules-registry-read, contradiction-asked-not-overwritten, retire-rule-delete, fix-spec-first]
org_required: true
---

# Scenario: a story that contradicts an existing business rule

## User story
"New accounts should keep an empty description when none is entered - the sales team fills it in later."

## Setup for the run
- The evaluator provides the `ZavaSales` project (`sh evals/setup/baseline.sh <work>`) (`<work>/ZavaSales`, a git repo, `account` / `contact` models
  generated, one existing Create plugin, its Build Report under `docs/features/<slug>/` and the rules registry under
  `docs/rules/`). The dev org `https://<dev-org>.crm.dynamics.com` is available **read-only**
  (`vela models` / `vela solution show` / `vela plan` / `vela inspect` / `vela logs`); never `vela apply`.

## What the skills must get right
- **Read the registry first:** `docs/rules/account.md` has **ACC-001** (a new account without a description
  gets "Created via Vela plugin") - the story contradicts it.
- **Ask, don't overwrite:** the agent asks the human (one question) whether the new rule replaces ACC-001,
  before any code.
- **Retire = delete:** after the answer, `ACC-001` and its tests are removed (git keeps the history); the new rule is added in English Given/When/Then; the Canvas lists both in `rules:`
  (`retire` / `add`) and `supersedes: [account-default-description]`.
- **The change itself:** the defaulting behaviour is removed (the `AccountDefaultDescription` step goes away -
  or the plugin is deleted), tests updated (a create with no Description keeps it empty), RED first.
- **Preview:** `vela plan --solution ZavaSales`; nothing of the old step is created.

## Success criteria (a clean pass)
1. A logged question to the human about the conflict with ACC-001, before the code.
2. Registry: ACC-001 removed with its tests + the new rule (English, Given/When/Then); Canvas `rules:` and `supersedes:`.
3. RED then green; review PASS; plan run; no apply.

## Planted-violation check (adversarial)
The review must BLOCK: (a) the code changed but `docs/rules/account.md` left with ACC-001 `active` →
**Required**; (b) a test still citing an ACC-001 case → **Required**.

## Human answers (evaluator only - never shown to the acting agent)
- Yes - the new rule replaces ACC-001; the default description is no longer wanted.
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
