---
scenario: feature-multi-rule
skills_exercised: [using-vela, vela-plan-review, vela-grill, vela-plugin-testing, vela-plugin-authoring, vela-code-review, vela-apply]
entity: account, contact
message: Create, Update
gotchas_exercised: [one-story-several-rules, rule-per-behaviour, rule-dependency-order]
org_required: true
---

# Scenario: one requirement, two rules on two tables

## User story
"Websites: an account's website is always stored as an https address, and a new contact without a website
takes its account's website."

## Setup for the run
- The evaluator provides the `ZavaSales` project (`sh evals/setup/baseline.sh <work>` → `<work>/ZavaSales`). The dev org `https://<dev-org>.crm.dynamics.com` is available
  **read-only**; never `vela apply`.

## What the skills must get right
- **One story, two rules:** one Canvas (`docs/features/<slug>/README.md`), one branch, declaring a new `ACC-` and a
  new `CON-` rule in `rules:` (ids free on the base), each with its own cases. Not split into two stories.
- **Dependency stated:** the contact rule relies on the account's stored (normalised) website, and its Given says so.
- **Grilled up front:** the human questions for both rules come before any code.
- **No layer split:** RED tests then implementation per rule, never a "tests" task apart.
- Existing rules untouched; `spec-check` clean.

## Success criteria (a clean pass)
1. One new Canvas declaring both rules, distinct ids not already used.
2. Questions logged before code; RED then green; one review PASS; plan run; no apply.

## Human answers (evaluator only - never shown to the acting agent)
- "http://x" becomes "https://x"; a website without a scheme gets "https://"; an empty website stays empty.
- Contact: on Create only, when the contact has a parent account with a website; later changes to the
  account do not propagate.
- If asked which security roles the users hold: "Salesperson" (a standard role of the dev org).
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
