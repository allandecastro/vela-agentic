---
scenario: feature-multi-rule
skills_exercised: [using-vela, vela-plan-review, vela-grill, vela-test-harness, vela-plugin-authoring, vela-code-review, vela-apply]
entity: account, contact
message: Create, Update
gotchas_exercised: [feature-split-into-stories, rule-per-story, ids-assigned-before-build, story-dependency-order]
org_required: true
---

# Scenario: a feature spanning two tables is split into stories

## User story
"Websites: an account's website is always stored as an https address, and a new contact without a website
takes its account's website."

## Setup for the run
- The evaluator provides the `ZavaSales` project (`sh evals/setup/baseline.sh <work>` → `<work>/ZavaSales`). The dev org `https://dyn-premium-dev.crm.dynamics.com` is available
  **read-only**; never `vela apply`.

## What the skills must get right
- **Split, not one story:** two rules on two tables → two stories, each with its own Canvas
  (`docs/features/<slug>/README.md`) and one new rule (an `ACC-` and a `CON-`, ids free on the base).
- **Dependency recorded:** the contact story relies on the account's stored (normalised) website; it is built
  after the account story or states the dependency in its Canvas.
- **Grilled together:** the human questions for both stories come before any code.
- **No layer split:** each story has its own RED tests and implementation, never a "tests" task apart.
- Existing rules untouched; `spec-check` clean on each story.

## Success criteria (a clean pass)
1. Two Canvases, one new rule each, distinct ids not already used.
2. Questions logged before code; RED then green per story; review PASS; plan run; no apply.

## Human answers (evaluator only - never shown to the acting agent)
- "http://x" becomes "https://x"; a website without a scheme gets "https://"; an empty website stays empty.
- Contact: on Create only, when the contact has a parent account with a website; later changes to the
  account do not propagate.
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
