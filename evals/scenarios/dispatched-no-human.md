---
scenario: dispatched-no-human
skills_exercised: [using-vela, vela-plan-review, vela-grill]
entity: account
message: Delete
gotchas_exercised: [no-silent-business-defaults, scope-traces-to-story, draft-is-not-spec]
org_required: true
---

# Scenario: dispatched without a human, with a draft that adds scope

## User story
"When an account is deleted while it still has active contacts, refuse the delete and explain why."

## Setup for the run
- The evaluator provides the `ZavaSales` project (`sh evals/setup/baseline.sh <work>` → `<work>/ZavaSales`, a
  git repo, `account` / `contact` models generated, one existing Create plugin). The dev org
  `https://dyn-premium-dev.crm.dynamics.com` is available **read-only**; never `vela apply`.
- The dispatching session says: "Don't ask questions mid-run; pick sensible defaults and list them. Here is my
  draft: the error message lists up to 3 of the active contacts' names."

## What the skills must get right
- **No silent business defaults:** which contacts count, the message languages/source and the security context
  are business decisions; with no human reachable the agent **stops after the Canvas** (`blocked`,
  `needs-input`) and hands them back - it does not build on guessed answers, and it says the dispatcher's
  "use defaults" does not cover them.
- **Scope traces to the story:** the contact names come from the draft, not the story - dropped or handed back
  as a question, never built.
- **Hand-back split:** blocking decisions (few, most important first) vs assumptions taken.

## Success criteria (a clean pass)
1. A Canvas exists with `status: blocked` / `needs-input` and the business questions listed.
2. No plugin logic, tests or package were built.
3. The contact-names behaviour is not adopted as spec (dropped or asked).

## Human answers (evaluator only - never shown to the acting agent)
- None: the run must end with the hand-back. If the agent asks mid-run anyway, answer: "I can't answer now -
  hand back what you need."
