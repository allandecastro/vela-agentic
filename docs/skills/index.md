---
_description: "The 11 skills of Vela Agentic, when each one triggers and the step of the build loop it covers"
---

# Skills

This page lists the skills of the pack, when each one triggers and the step of the [build loop](../build-loop.md) it
covers. It is for developers who want to know which skill is doing what during a run, or who run one directly.

A skill is a `SKILL.md` file in the [Agent Skills](https://agentskills.io) format. The assistant loads it when a
task matches its description; a human can also run one by name, such as `/vela-grill`. Each skill bundles a copy of
the references it cites, so it works once installed.

| Skill | Triggers when | Step |
| --- | --- | --- |
| [using-vela](using-vela.md) | Any Vela work starts, or it is unclear which skill applies. | Entry point |
| [vela-plan-review](vela-plan-review.md) | A story has been interpreted and the plan needs challenging before any code. | Plan |
| [vela-grill](vela-grill.md) | A story is ambiguous and only the human can resolve it. | Plan |
| [vela-scaffold](vela-scaffold.md) | A solution or a component must be created. | Scaffold |
| [vela-models](vela-models.md) | A plugin needs typed models, or committed models must be checked for drift. | Model |
| [vela-plugin-testing](vela-plugin-testing.md) | Behaviour must be proved without an org: failing tests first, or a bug reproduced. | Test, verify |
| [vela-plugin-authoring](vela-plugin-authoring.md) | The failing tests exist and the plugin logic must be written. | Implement |
| [vela-custom-api](vela-custom-api.md) | A story asks for an operation someone calls, rather than a reaction to a table event. | Plan to implement |
| [vela-code-review](vela-code-review.md) | Tests are green and analyzers clean, before the apply gate. | Review |
| [vela-apply](vela-apply.md) | A reviewed plugin must be packaged, previewed or deployed. | Package, preview, gate |
| [vela-debug-plugin](vela-debug-plugin.md) | A plugin does not fire, fires on the wrong event, throws or gives wrong results. | Debug |

## Rules every skill follows

- Drive Vela through the `vela` CLI only, and confirm flags with `vela <command> --help`.
- Run `vela version` before relying on a feature.
- Announce the skill in use: `Using <skill> to <purpose>`.
- Back each claim with the tool's output: build summary, test runner summary, review findings, `vela plan` output.
- Stop before `vela apply`.

The skills' source is in
[`skills/`](https://github.com/allandecastro/vela-agentic/tree/v0.6.0/skills); the rules every agent follows are in
[`AGENTS.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/AGENTS.md).
