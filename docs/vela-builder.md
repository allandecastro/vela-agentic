---
_description: "The vela-builder agent: drives a user story through the build loop and stops at the apply gate"
---

# vela-builder

This page describes `vela-builder`, the agent that takes a user story through the whole build loop. It is for
developers who hand it a story and for reviewers who read the result.

## What it does

`vela-builder` loads [using-vela](skills/using-vela.md), then the skill each step names, and works through the
[build loop](build-loop.md): intake, plan, challenge, scaffold, model, failing tests, implementation, verification,
review, package and preview. It is autonomous up to the preview: the org is only read. It then writes the Build
Report and stops.

- **Questions:** autonomous means no org write, not no question. A business decision the story leaves open goes to
  the human through [vela-grill](skills/vela-grill.md). With no human reachable, it stops after the Canvas and hands
  back the questions.
- **Review:** the only agent it dispatches is the read-only [vela-reviewer](vela-reviewer.md).
- **Pull request:** it branches before scaffolding, opens a draft pull request once the Canvas exists, and marks it
  ready only when the tests are green, the analyzers are clean and the review has no open Critical or Required
  finding. The pull request body is the Build Report. No AI attribution.
- **Run trace:** it keeps one row per step in `.vela-runs/<slug>/trace.md`.
- **Resume:** an interrupted story restarts from the Canvas, the trace and the git log, at the first step with no
  evidence. It never asks again what the Canvas records.

## What it never does

- Run `vela apply` or pass `--auto-approve`, unless the user authorized an unattended apply for that run. A ready
  or merged pull request does not mean the org was written.
- Build on a guessed business decision.
- Scaffold, package or open a pull request for a story it marked `status: blocked`.

## Tools

`Bash`, `Read`, `Edit`, `Write`, `Grep`, `Glob`, `Skill` and `Agent`. On Claude Code `using-vela` is preloaded;
on Copilot the generated agent loads the skills with Copilot's `skill` tool.

Source: [`agents/vela-builder.agent.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/agents/vela-builder.agent.md).
