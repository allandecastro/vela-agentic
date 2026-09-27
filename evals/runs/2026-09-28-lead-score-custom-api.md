---
scenario: lead-score-custom-api
date: 2026-09-28
verdict: fail
vela_cli: 0.19.6
framework: 0.28.2
runner: fresh subagent, local, no org
---

## Loop outcome
- Version: `vela version` -> `vela 0.19.6` (exit 0).
- Intake/Challenge (vela-plan-review): routed to **vela-custom-api** (called operation, not a table step). Canvas
  written: global, Function ("pure computation, GET-callable" per the skill), `email` (string, required) ->
  `leadScore` (int), blank/missing -> `InvalidPluginExecutionException`. Assumptions: prefix `zava`, solution unnamed.
  Draft PR: skipped (eval).
- Scaffold: `vela init Zava --prefix zava -o .` (exit 0, 6 projects `zava.*` under `./Zava`); baseline
  `dotnet build Zava.sln -c Release` exit 0, `0 Error(s)`, 4 demo VELA013. `vela add customapi ScoreLead --global
  --function --prefix zava` (exit 0, `zava_ScoreLead`); `vela add test ScoreLead --kind customapi` (exit 0).
- Model: not needed (no table attributes). `vela models` not run.
- Test RED (Mono + xunit.console 2.9.2, `-parallel none`): `zava.Plugins.Tests  Total: 6, Errors: 0, Failed: 6, Skipped: 0` (exit 1).
- Implement: global form per vela-custom-api step 5; GREEN `Total: 6 ... Failed: 0`; full suite `Total: 15 ... Failed: 0`.
- Review round 1 (self): Required - an input with no '@' ("fortune500.com") scored 55 against the Canvas
  assumption. Canvas updated first, RED `Total: 7, Failed: 1` (Expected 10, Actual 55), fixed, GREEN 16/16.
- Review round 2 (isolated vela-reviewer): **Critical** - `.AsFunction()` cannot be called by the story's
  flows. Checked against Microsoft Learn (custom-api): "Currently, the Microsoft Dataverse Connector only enables
  performing actions. If you need the operation to be performed by using Power Automate, you should create your
  custom API as an Action." and "you can't change whether a custom API is a Function or an Action after you create
  it". Canvas changed to Action first, RED registration test `Total: 8, Failed: 1` (IsFunction Expected False,
  Actual True), `.AsAction()`, GREEN: `zava.Plugins.Tests  Total: 8 ... Failed: 0` (class), `Total: 17, Errors: 0,
  Failed: 0, Skipped: 0` (suite), `zava.Integrations.Tests  Total: 3, Errors: 0, Failed: 0, Skipped: 0`.
- Review round 3 (isolated): **PASS**, 4 Nits.
- Verify: `dotnet build Zava.sln -c Release` -> `Build succeeded.` `0 Error(s)`; VELA diagnostics only the 4
  scaffold-demo VELA013 in `AccountPostCreatePluginTests.cs` / `SecurityExampleTests.cs`; none in authored files.
- Package: skill's `dotnet pack` produced an assembly-less package (finding 2); used `dotnet build -c Release`
  -> `Zava/artifacts/zava.Plugins.1.0.0.nupkg`, sha256 `679aebad217d02010d9f2282a6bb44bfc3a6f28f44d1b8a38d8f2e76092d1150`,
  contains `zava.Plugins.dll`; definition read from the packaged dll: `zava_ScoreLead binding=Global
  isFunction=False steps=None`, `in email System.String optional=False`, `out leadScore System.Int32`.
  Sign: skipped (no certificate). Plan: skipped - no org; would have run
  `vela plan -p Zava/artifacts/zava.Plugins.1.0.0.nupkg --connection-string "$DATAVERSE_CONNECTION_STRING" --out plan.json`.
- Apply gate: Build Report written (`docs/vela-builds/lead-score-custom-api.md`, Canvas in
  `lead-score-custom-api.canvas.md`); stopped. `vela apply` never run.

### Planted-violation check
Each variant was a separate copy (`planted-a|b|c/`); the real `Zava/` was never modified. Each builds with
`0 Error(s)` and no VELA diagnostic in the changed files, and its ScoreLead tests pass (`Total: 7, Failed: 0`),
so only the review can catch it. Each diff + the Canvas went to a fresh isolated `vela-reviewer`.

| Variant | Planted | Expected | Reviewer result | Gate |
| --- | --- | --- | --- | --- |
| a | request parameter `lead.email` (code + tests) | Critical | **Critical** (+ Required: Canvas divergence) | BLOCK - match |
| b | blank email -> `leadScore = -1`, tests assert -1 | Required | **Critical** (+ 2 Required: tests lock in the defect, Canvas divergence) | BLOCK - severity higher than expected |
| c | Function creates a `task` via `ctx.UserService.Create` | Required | **Critical** | BLOCK - severity higher than expected |

The framework's `CustomApiDefinitionReader` extracted `in lead.email` for variant (a) without complaint.

## Findings

### Skill defects
1. **blocker** - `skills/vela-custom-api/SKILL.md` step 2 said "**Action or Function?** Side effects (writes, sends) -> **Action**. Pure read / computation, callable with GET -> **Function**."
   `references/plugin-authoring-api.md` says the same ("`.AsAction()` (POST-style, side effects) vs
   `.AsFunction()` (GET-style, read-only)"), and the scenario's criterion 2 calls Function "defensible".
   - What happened: a literal reading picked Function for a story whose callers are flows. Build, tests and
     self-review all passed with `.AsFunction()`. An isolated reviewer caught it using knowledge from outside the
     pack, and Microsoft Learn confirms that the Dataverse connector only performs Actions and that IsFunction
     can't be changed after creation. The skill would have shipped an API the flows can't call, and fixing it
     later means deleting and recreating it.
   - Correct path: callers include Power Automate / workflows / "flows" -> **Action** (`vela add customapi <Name>
     --action`, `.AsAction()`) even when side-effect-free. Function only for GET/Web API callers with at least one
     response property. Add this to vela-custom-api step 2, the rationalizations, review-checklist.md's Custom API
     line, and fix the scenario's criterion 2.
2. **blocker** - several skills say to package with `dotnet pack`:
   - `skills/vela-apply/SKILL.md` step 2: "**Package** the final code: `dotnet pack` as the project defines (e.g. `-c Release`)".
   - `skills/using-vela/SKILL.md` step 10: "`dotnet pack` -> `vela sign` ...".
   - `agents/vela-builder.agent.md` step 10: "`dotnet pack`".
   - `build-report-template.md` run-trace row: "`dotnet pack -c Release -o artifacts`".

   What happened: on a fresh scaffold, `dotnet pack -c Release -o artifacts` exits 0 and prints "Successfully
   created package '.../artifacts/zava.Plugins.1.0.0.nupkg'" plus `warning NU5128 ... Add lib or ref assemblies for
   the net462 target framework`. `unzip -l` of that package lists **no .dll**. The scaffold's own csproj says:
   "`dotnet build -c Release` produces the deployable package, NOT `dotnet pack` (run cold it skips the publish and
   emits an assembly-less package that vela plan rejects with "No assemblies found")". With no org the preview is
   skipped, so nothing would catch the empty package, and its hash would go into the Build Report.

   Correct path: `dotnet build <Sln> -c Release`, which writes `artifacts/<Prefix>.Plugins.<ver>.nupkg` through
   GeneratePackageOnBuild. Verify with `unzip -l <pkg> | grep <Prefix>.Plugins.dll`. Observed: the package holds
   `zava.Plugins.dll`, `zava.Shared.dll`, `Vela.Plugins.dll` and `Vela.Messages.dll`.
3. minor - `skills/vela-code-review/references/review-checklist.md`, Custom API line ("no parameter/unique name
   contains a dot ...; a Function has no side effects; invalid input throws `InvalidPluginExecutionException`
   (not an error code in an output)") gives no severity per item.
   - What happened: the scenario expects (b) and (c) to be Required. Isolated reviewers rated both **Critical**,
     applying "Critical - will fail or misbehave on a live org". The gate result (BLOCK) was correct either way.
   - Correct path: put the severity on each Custom API item (dot -> Critical; sentinel output / Function writing ->
     Required), the way the Stage and Recursion items already do, or align the scenario with Critical.
4. minor - several skills assume a plugin step:
   - `agents/vela-builder.agent.md` step 7: "Implement - `vela-plugin-authoring`: real `EntityPluginBase`/`OnExecute` surface ...".
   - Builder step 1 and vela-plan-review step 1: intake is "entity, message, stage, mode, images, filtering attributes".
   - The Canvas template frontmatter has only step fields (`stage`, `filtering_attributes`, `images`) and no
     binding, Action/Function or parameter fields.
   - Review-checklist Axis 1 checks "Message / stage / mode", with no Custom API equivalent.

   What happened: for a Custom API, vela-plugin-authoring has nothing to apply; the real guidance is
   vela-custom-api step 5. I added a `custom_api:` block to the Canvas myself.

   Correct path: builder step 7 should read "vela-plugin-authoring, or vela-custom-api step 5 for a Custom API".
   Add Custom API fields to the Canvas template (binding, kind, request/response, allowed processing steps,
   callers) and an Axis 1 item for them.
5. minor - `skills/vela-scaffold/SKILL.md` step 1, `skills/vela-apply/SKILL.md` step 1 and AGENTS.md say to
   "confirm the exact flags with `vela init --help`" and "`vela plan --help` / `vela apply --help` / `vela sign
   --help`".
   - What happened: all of these print the same global usage screen. Only `vela add --help` prints command-specific
     help, and it omits `--prefix` for `add customapi` (cli-surface.md already notes this).
   - Correct path: say that `vela --help` is the flag source for init/plan/apply/sign, and that `vela add --help`
     and `vela models --help` have their own pages.
6. minor - `skills/vela-scaffold/SKILL.md` step 2: "`vela init <Name> [--prefix <pub>] [-o <dir>]` ... emits 6
   projects ... `<Prefix>.Shared`, `<Prefix>.Plugins`".
   - What happened: `vela init Zava --prefix zava -o .` created a `./Zava/` subfolder, and the projects and
     namespaces take the prefix's casing (`zava.Plugins`, namespace `zava.Plugins.GlobalCustomApis`).
     Dataverse publisher prefixes are lowercase, so following "use the publisher prefix" gives lowercase project
     names. My Canvas said `src/Zava.Plugins`, and two reviewers raised the mismatch as a Nit.
   - Correct path: say that `<Name>` becomes a subfolder of `-o`, and that the `--prefix` casing names the
     projects and namespaces.
7. minor - `references/plugin-authoring-api.md` said "Verify with the definition the framework extracts
   (`CustomApiDefinitionReader`)" but gives no API.
   - What happened: I found it with `monop`. The API is
     `Vela.CustomApi.CustomApiDefinitionReader.GetCustomApiDefinitions(Assembly)`, returning
     `CustomApiDefinition { UniqueName, IsFunction, BindingType, AllowedCustomProcessingStepType, InputParameters,
     OutputParameters }`. The parameter elements are `CustomApiParameterDefinition { Name, IsOptional,
     ParameterTypeName }`; `UniqueName` and `Type` don't exist on it (CS1061).
     `.AllowedCustomProcessingSteps(None)` in the skill has to be written
     `CustomApiAllowedCustomProcessingStepType.None` (`using Vela.CustomApi;`).
   - Correct path: document these signatures, plus a registration test recipe: assert `IsFunction`, `BindingType`,
     parameter names and optional flags.
8. minor - `references/harness-api.md` said "`vela add test <Name> --kind customapi` generates exactly this
   shape", where the shape includes `crm` and `.WithOrganizationService(crm)` marked "REQUIRED".
   - What happened: the generated test is `LocalPluginContext context = PluginContext.ForMessage("zava_ScoreLead").Build();`,
     with no org service. It is only needed when the handler resolves `IOrganizationService`.
   - Correct path: describe the generated shape accurately, and say `.WithOrganizationService(crm)` is required
     only when the handler reads or writes through a service.
9. minor - `references/dataverse-gotchas.md` said "Parameter/unique names contained a dot. Use dot-free unique
   names (the CLI self-heals, but verify)."
   - What happened: locally, nothing rejects or heals `lead.email`. The build had no diagnostic, the tests
     passed, and `CustomApiDefinitionReader` returned `in lead.email`. Whether `vela plan` self-heals could not be
     checked without an org.
   - Correct path: state that no local gate catches it and that the review (or a registration test on the
     definition) is the only guard.
10. minor - vela-apply and the Build Report template never mention that the scaffold's demo components (Account/Contact demo plugins, `Ping`, `AccountEstimateValue` ...) sit in the same `zava.Plugins` package and would be registered by `apply`; the skills only discuss demo VELA013. Correct path: tell the builder to remove the demo components (or list them in the Gate section) before the preview.
11. minor - `build-report-template.md` said both the Canvas and the Build Report are "committed under `docs/vela-builds/<slug>.md`" (one path, two artifacts). I kept the Canvas as `<slug>.canvas.md`. Correct path: name both files, or say the Build Report replaces the Canvas in place.
12. minor (not executed - git excluded by this eval) - `skills/vela-code-review/SKILL.md` step 1 said "`git diff <base>...HEAD`". The builder has no commit step before Review, so a three-dot diff against HEAD would leave out uncommitted work. Correct path: `git diff <base>` (working tree), or commit before review.

### Environment (not skill defects)
- E1: no Dataverse org, so `vela models` / `vela plan` / `vela inspect` were skipped and the plan command recorded. I could not check what `plan` does with a dotted parameter or an assembly-less package.
- E2: git operations excluded, so the review diff came from `diff -ruN -x bin -x obj -x artifacts baseline Zava` against a snapshot taken right after `vela init`.
- E3: no signing certificate, so `vela sign` was skipped and the package recorded as unsigned.
- E4: the host has no registered `vela-reviewer` agent type, so reviewers were fresh general-purpose subagents told to act as `agents/vela-reviewer.agent.md`, read-only, given only the diff and the Canvas.

## Fixes
- none yet (eval run; findings feed the next GREEN step).

## Verdict
**fail** - 2 blocking findings:
1. vela-custom-api's Action/Function rule sends a flow-called operation to Function, which Power Automate cannot call.
2. The `dotnet pack` packaging step in vela-apply, using-vela, vela-builder and the template produces a package with no assembly.

The run reached a correct end state only because an isolated reviewer brought in outside knowledge and because
the scaffold csproj's comment contradicted the skill. Success criteria 1, 3, 4 and 5 were met. Criterion 2 was
met as written, but the Function it allows is wrong for this story.

All three planted violations were blocked; (b) and (c) came back one severity higher than the scenario expects.

The next run must re-check:
- Action is chosen for a flow-called API straight from the skill.
- Packaging follows the skill literally and yields a package containing `<Prefix>.Plugins.dll`.
- The planted (b)/(c) severities match whatever the checklist pins.

## Fixes (iteration 1)

7ec62f8 (Action when flows call it; definition reader; dotted names; builder routing; Canvas Custom API block), 21eb4e0 (dotnet build packaging), 7fef67e (Custom API severities), f6b5aa3 (org service optional in Custom API tests)

Next: re-run this scenario against the fixed skills and record iteration 2.
