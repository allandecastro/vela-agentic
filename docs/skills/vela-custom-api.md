---
_description: "The vela-custom-api skill: designs, tests and implements a Custom API through the same build loop"
---

# vela-custom-api

This page describes `vela-custom-api`, the skill for operations that code, a flow or a client calls by name. It is
for developers who will call the API and need to know which design choices the agent records.

## When it triggers

When a story asks for an operation someone calls, with inputs and outputs ("expose", "call", "endpoint", "compute on
demand"), rather than a reaction to a table event. Also when an existing Custom API needs a new parameter, a change
of behaviour or tests.

## What it does

It runs the same [build loop](../build-loop.md), with these decisions recorded in the Canvas, each with a reason:

- **Global or bound** to one table.
- **Action or Function**, by caller first: called from Power Automate means an Action, even when it only reads. The
  kind cannot change after creation.
- **Parameters:** plain identifier names, types, required or optional, and outputs. The unique name carries the
  publisher prefix.
- **Errors:** which invalid inputs fail, and with which message.
- **Exposure:** private or not, the privilege callers need, whether others may add steps on it.

It scaffolds with `vela add customapi <Name> --prefix <publisherPrefix>`, writes a test that pins the definition (a
flow breaks when it changes) and one per acceptance case, including invalid inputs, then implements to green. See
[Write a Custom API](../../guides/custom-apis.md) and
[Custom APIs](https://learn.microsoft.com/power-apps/developer/data-platform/custom-api) on Microsoft Learn.

## What it reads and writes

- Reads `PROJECT.md` for the publisher prefix.
- Writes the Custom API class, its tests and the Canvas decisions. When a form or ribbon button must call the API,
  it records what the client must call as an open item: client scripts are outside the pack.

## What it never does

- Make a Function that writes, or one a flow calls.
- Use a parameter name that is not a plain identifier.
- Report an error through an output instead of a fault.

Source: [`skills/vela-custom-api/SKILL.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/skills/vela-custom-api/SKILL.md).
