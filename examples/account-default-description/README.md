# Example: a story built by the Vela agent

Story: "When an Account is created, if its Description is empty, set it to 'Created via Vela plugin'."
Produced by `vela-builder` on the lean pack (validation run 2026-10-17e, vela 0.26.2 / Vela.Plugins 0.37.0), unedited:

- `build-report.md` - the Vela Canvas grown into the Build Report (decisions, acceptance cases, evidence, gate)
- `AccountDefaultDescription.cs` - the plugin
- `AccountDefaultDescriptionTests.cs` - the harness tests (written first, seen RED, then GREEN)

> **A snapshot, kept unedited.** It predates later conventions: one `<Entity>Plugin` class per table with
> behaviour-named handlers, `PROJECT.md`, the rules registry (`docs/rules/`, `[Trait("Case", ...)]` on every
> test) and `PluginPipeline` as the default test runner. The skills, not this example, are the current guide.
