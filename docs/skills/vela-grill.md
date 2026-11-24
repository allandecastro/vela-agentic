---
_description: "The vela-grill skill: interviews the human to resolve an ambiguous story before building"
---

# vela-grill

This page describes `vela-grill`, the skill that interviews the human when a story is too ambiguous to build. It is
for the person who answers the questions.

## When it triggers

When a story is underspecified and only the human can resolve it, or when a human runs `/vela-grill`. A session
that can talk to the human runs it before dispatching [vela-builder](../vela-builder.md) on such a story.

## What it does

It restates the story, then asks one focused question per decision, with choices or a proposed default and a
one-line answer expected. Independent questions may share a turn, numbered. Only business decisions go to the
human; platform facts are the agent's. In rough order:

- **Meaning:** which table and column each story term means.
- **Direction:** which record drives the change and which one is written.
- **Trigger:** which message and columns, and whether other events reach the same outcome.
- **Timing:** Sync (blocks the user, rolls back together) or Async (never blocks, fails on its own).
- **Data:** exact values, defaults and edge cases.
- **Security context and roles:** the calling user or elevated, and the exact role names when behaviour depends on
  rights.
- **Messages the user sees:** languages and where the texts live.
- **Target solution:** when `PROJECT.md` does not give it.

It stops once every branch that changes the registration or the acceptance cases is resolved, then hands back to
[vela-plan-review](vela-plan-review.md).

## What it reads and writes

- Reads the ADRs that touch the story and the `docs/rules/` files of the tables involved, so it never asks what they
  already answer.
- Writes the answers into the Vela Canvas as the human's decisions; platform facts go under `assumptions:`.

## What it never does

- Ask broad, open questions instead of ones tied to the registration or the cases.
- End with a branch unresolved, or treat "use the defaults" as an answer to a question not yet asked.
- Ask for the publisher prefix: `vela solution show` reads it.

Source: [`skills/vela-grill/SKILL.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/skills/vela-grill/SKILL.md).
