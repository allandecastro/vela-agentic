---
_description: "The vela-code-review skill: spec-check, then an isolated review on spec and standards before the apply gate"
---

# vela-code-review

This page describes `vela-code-review`, the skill that reviews a change between verification and the apply gate. It
is for developers who read the findings and decide on the change.

## When it triggers

Once the tests are green and the build has no analyzer violation, before the Build Report.

## What it does

1. Commits, then takes the diff against the branch point.
2. Runs **`spec-check`**, a script bundled with the skill (`dotnet run`). It fails when the rules registry changed
   outside the rules the Canvas declares, when an existing test was changed or deleted for a rule the story does not
   change, or when the story takes a rule id or ADR number already used on the base branch. A failure blocks before
   any review.
3. Dispatches [vela-reviewer](../vela-reviewer.md) with the real material pasted in: the diff, the Canvas, the RED
   and GREEN test output, the build's diagnostic lines, the `spec-check` output and the run trace.
4. Saves the reviewer's output verbatim in `.vela-runs/<slug>/review.md`, before acting on it.
5. Fixes each Critical or Required finding, verifies again and asks for a scoped re-review. A full review again only
   when a fix touches the registration, the security context, data access, an outbound call or most of the code.

The review has two axes: **spec** (the diff against the Canvas cases and decisions) and **standards** (analyzer
intent, Dataverse pitfalls, registration legality, SOLID and DRY).

## What it reads and writes

- Reads the diff, the Canvas, `docs/rules/` and `docs/adr/`.
- Writes `.vela-runs/<slug>/review.md` and the findings in the Build Report.

## What it never does

- Reach the gate with an unresolved Critical or Required finding.
- Dismiss a finding on its own: only the reviewer or the human closes one.
- Fix a rule's wording in `docs/rules/` during the build; that goes to the gate for the human.
- Self-review when a reviewer agent can be dispatched. When none can, the Build Report says so.

You can run `spec-check` in your own CI: see
[`spec-check.cs`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/skills/vela-code-review/scripts/spec-check.cs).

Source: [`skills/vela-code-review/SKILL.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/skills/vela-code-review/SKILL.md).
