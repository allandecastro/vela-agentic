---
_description: "Short answers to common questions about running Vela Agentic, and what to do when a run stops"
---

# FAQ and troubleshooting

Short answers to common questions about running the pack, and what to check when a run stops. For problems with
Vela itself, see [Troubleshooting](../guides/troubleshooting.md) and the [Vela FAQ](../reference/faq.md).

## Running the pack

### Does the agent need a Dataverse environment?

Yes, for the steps that read it: `vela models`, `vela solution show` and `vela plan`. A new project has no models,
so without an org the plugin does not compile. The only offline route is `vela models --from-solution` with an
exported solution zip. When the connection fails, the agent records the command and its exit code and does not
write a model by hand. See [Early-bound models](../guides/models.md).

### Why does the agent ask me questions?

A business decision is the human's: what a story term means, Sync or Async when the user would notice, the security
roles involved, what a denied read or write must do, the languages of a message the user sees. The agent asks one
numbered question per decision and records the answer in the Canvas. Platform facts it decides itself and lists as
assumptions.

### Can it run unattended?

Up to the preview. When the agent is dispatched with no way to ask, it stops after the Canvas if a business decision
is open, and hands back the questions with the Canvas set to `status: blocked`.

### Will it deploy?

Not on its own. It stops at the apply gate with the exact `vela apply` command in the Build Report. To let it apply
in a run, authorize it explicitly for that run; with the [deploy guard](hooks.md), also start the host with
`VELA_APPLY_APPROVED=1`.

### Can I use a skill without the builder?

Yes. Every skill loads when a task matches its description, and a human can run one by name, such as `/vela-grill`.
There is no build or apply slash command; the loop is the [vela-builder](vela-builder.md) agent.

## When a run stops

### The preview says the solution is missing or managed

`vela plan` exits `4` before any write. The solution must exist, be unmanaged in the target org and use the
publisher prefix in `PROJECT.md`. A managed solution means the connection points at a test or production org. The
agent asks for the right solution or org. See [Plan and apply](../guides/plan-apply.md).

### The preview is unavailable

When the connection fails (exit `6`), the Build Report records `plan_preview: unavailable` with the exact command
and exit code. Run that command yourself with a working connection before you apply.

### The CLI is older than the pack expects

The session hook says so at start. Run `vela update`. The agent stops only if a feature the task needs is missing.

### The review blocks

A Critical or Required finding blocks the gate. The agent fixes it, reruns the tests and asks for a scoped
re-review. A finding the agent thinks is wrong is answered with evidence in a new round or put to you; the agent
never closes it alone.

### `spec-check` fails

The rules registry or an existing test changed outside what the Canvas declares, or the story reuses a rule id
already on the base branch. The build does not bend the spec: the agent goes back to design with you, or fixes the
code. See [The build loop](build-loop.md).

### Tests crash on macOS or Linux

Plugin tests target .NET Framework 4.8, which `dotnet test` cannot host there. The skills use Mono with the xUnit
console runner and `-parallel none`; a crash without `-parallel none` is an environment crash, not a test failure.
See [Testing](../guides/testing.md).

## Reporting a problem

Problems with the skills, the agents or these pages: [vela-agentic issues](https://github.com/allandecastro/vela-agentic/issues).
Problems with the `vela` CLI or the framework: [Vela issues](https://github.com/allandecastro/vela/issues).
