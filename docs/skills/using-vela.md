---
_description: "The using-vela skill: the entry point that maps the build loop to the other skills"
---

# using-vela

This page describes `using-vela`, the skill an agent reads first for any Vela work. It is for developers who want
to know how the agent decides which skill runs at each step.

## When it triggers

At the start of any Vela work, or when it is unclear which skill applies. [vela-builder](../vela-builder.md) loads
it before anything else.

## What it does

It maps each step of the [build loop](../build-loop.md) to its skill, and sets two rules about the size of a story:

- **One requirement, several rules** stays one story: one Canvas, one branch, one pull request. The agent never
  splits it into several stories or into layer tasks; only the human splits a backlog item.
- **A small story** (one step on one table, no outbound call, no open security decision) keeps the same gates on a
  short track: a Canvas with front matter and cases only, one full review.

It also states the rules the other skills share: the CLI is the contract, check the version, announce the skill,
evidence over claims, stop before `vela apply`. For framework detail the pack does not carry, it points the agent to
Vela's [`llms.txt`](https://allandecastro.github.io/vela/llms.txt).

## What it reads and writes

It reads the pack's references on the CLI surface, Dataverse pitfalls and registration rules. It writes nothing.

## What it never does

It does not run a step itself, and it never allows a write to an org without a human's go-ahead.

Source: [`skills/using-vela/SKILL.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/skills/using-vela/SKILL.md).
