---
scenario: contact-association
date: 2026-09-29
verdict: fail
vela_cli: 0.21.0
framework: 0.29.3
runner: fresh subagent, local, no org
---

## Loop outcome
- 0 version: `vela version` -> vela 0.21.0 (exit 0); dotnet 10.0.302; Mono 6.14.1.

- 1 intake/plan/challenge (vela-plan-review): Canvas drafted outside the project (`canvas-draft.md`), assumptions flagged (listcontact_association, overwrite, Disassociate out of scope, prefix/solution `tbd`).
- 2 scaffold: `vela init ContactStamp --prefix tbd --no-integrations --no-console -o <scratch>` exit 0 (resolved Vela.Plugins 0.29.3); baseline build 0 errors / 4 VELA013 (demo tests). git init, baseline commit, branch `feat/contact-marketing-list-stamp`, demos + unused Account model removed (build 0 err / 0 warn), Canvas committed to docs/vela-builds/.
- 3 `vela add plugin ContactMarketingListStamp --entity Contact --message Associate` exit 0 -> `EntityPluginBase<Contact>`, `RegisterStep().OnAssociate().PostOperation().Sync()...Handle(OnExecute)`, `IAssociatePostContext<Contact>`. Probe (reflection, not committed): GetStepDefinitions() -> EntityLogicalName = contact, Message = Associate. Build 0/0.
- 4 model: SKIPPED (no org). Would run: `vela models --entities contact,list --out src/tbd.Shared/Models/Generated --overwrite --url <org>`. Stand-in `Description` added to Contact.cs with the STAND-IN comment.
- 5 test RED: `vela add test ContactMarketingListStamp --kind plugin --entity Contact` exit 0; replaced body with A1-A6 on PluginPipeline. `mono xunit.console.exe ... -parallel none` exit 1: `Total: 6, Errors: 0, Failed: 4` (A1,A2,A3,A6 fail; A4/A5 guard cases pass before code). A1 failure = `Assert.Contains() Failure: Filter not matched in collection / Collection: []` - the Associate step did NOT fire when Target = list.
- 6 implement (attempt 1, as the Canvas said): contact-bound handler checking relationship + entity types. Suite: `Total: 6, Errors: 0, Failed: 3` - A1/A3/A6 (Target = list) still fail, `ExecutionLog` empty: the harness fires an Associate step only when the Target's entity == the plugin's TEntity. Probes (not committed): `EntityPluginBase<Entity>` -> EntityLogicalName 'entity'; a model with logical name 'none' -> pipeline ExecutionLog 0. No builder member (IAssociatePostOperationConfig: Disabled/Handle/WithDescription/WithExecutionOrder/WithImpersonation/WithSecureConfig/WithStepKey/WithSupportedDeployment/WithUnsecureConfig) makes a step message-only.
- 6b Canvas updated first (Sync log 1), then DEVIATION: stand-in `List` model CLASS (beyond the sanctioned property stand-in), `vela add plugin MarketingListContactStamp --entity List --message Associate` exit 0, `vela add service MarketingListMembershipStamp --entity Contact` exit 0; both thin handlers delegate to the service.
- 7 verify: `dotnet build ContactStamp.sln -c Release` -> 0 Warning(s), 0 Error(s). `mono ~/.nuget/packages/xunit.runner.console/2.9.2/tools/net462/xunit.console.exe tests/tbd.Plugins.Tests/bin/Release/net462/tbd.Plugins.Tests.dll -parallel none` exit 0: `Total: 6, Errors: 0, Failed: 0, Skipped: 0`.
- 8 review: isolated vela-reviewer dispatched (fresh subagent, read-only) with diff file, Canvas, RED/GREEN lines, Run trace - result below.
- 8 review result: **BLOCK** - Critical: Associate step bound to a primary entity (contact, list) in both plugins (the exact gotcha); Required: Canvas contradicts itself (Approach/Safeguards say "matched by message", code is entity-bound); Required: AddMember/AddListMembers question not marked blocking. 7 Nits (A2 does not assert which step fired; no Assert.Single per link; unconditional write; duplicated ConfigureServices; List stand-in class; Array.Empty; test class naming).
- 9 fix loop: NOT possible locally - the Critical needs either a Vela message-only registration (does not exist in 0.29.3) or a dev org to prove the per-entity Associate filters (`vela plan`). Gate unreachable -> stopped.
- 10 package/plan: not run (blocked at review). Would run: `rm -rf artifacts && dotnet build ContactStamp.sln -c Release`, `unzip -l artifacts/tbd.Plugins.1.0.0.nupkg | grep tbd.Plugins.dll`, `shasum -a 256 artifacts/tbd.Plugins.1.0.0.nupkg`, `vela plan -p artifacts/tbd.Plugins.1.0.0.nupkg --url <org> --out plan.json` - skipped (no org, and review BLOCK). `vela apply` never run.

## Findings
1. **blocker** - `references/dataverse-gotchas.md` ("Match the message regardless of primary entity"), `registration-rules.md` (matrix row "n/a - match by **message**, not primary entity"), `vela-plan-review/SKILL.md` ("Associate/Disassociate matched by **message**, not primary entity (else never fires)"), `vela-plugin-authoring/SKILL.md` red flag. The pack gives NO Vela way to do this. `vela add plugin X --entity Contact --message Associate` generates `EntityPluginBase<Contact>` + `RegisterStep().OnAssociate()`, whose `GetStepDefinitions()` reports `EntityLogicalName = contact` - the entity-bound shape the gotcha forbids. The Associate builder (`IAssociatePostOperationConfig`) has only Disabled/Handle/WithDescription/WithExecutionOrder/WithImpersonation/WithSecureConfig/WithStepKey/WithSupportedDeployment/WithUnsecureConfig; `EntityPluginBase<Entity>` -> 'entity'; a model with logical name 'none' does not fire in `PluginPipeline` either. Observed: `A1_ListTarget_ContactRelated_StampsContact [FAIL] ... Assert.Contains() Failure: Filter not matched in collection / Collection: []` - the step never fires when the Target is `list`. The CLI binary has "Cannot register step '...': no message filter exists for entity '...' on message '...'", so on an org where Associate only has the `none` filter, `vela plan` would likely reject it (unverified, no org). Workaround used (a deviation): one registration per side (`EntityPluginBase<Contact>` + `EntityPluginBase<List>`) plus a shared service. The reviewer rated it Critical. Correct path: the pack must state what Vela 0.29.x actually supports for Associate (framework gap or a verified pattern), plus what `vela plan` does with it. Until then the scenario cannot pass.
2. **blocker** - `vela-plugin-authoring/references/plugin-authoring-api.md` "Handler context" covers only Create/Update/Delete contexts. There is nothing on `IAssociatePostContext<T>` / `ctx.Request` (`AssociateRequest`: `Target` EntityReference, `Relationship.SchemaName`, `RelatedEntities` EntityReferenceCollection). The scenario requires the handler to check the relationship name and entity types; I had to reflect over `Vela.Plugins.dll` to find the API. Correct shape: `ctx.Request.Relationship.SchemaName`, `ctx.Request.Target.LogicalName`, `ctx.Request.RelatedEntities` (the only example was the deleted demo `AccountMessageReference`).
3. **blocker** - `vela-test-harness/references/harness-api.md` has no Associate recipe. It needs: `PluginPipeline.Empty().Register<P>().WithManyToMany("listcontact_association","listmember","list","listid","contact","entityid").Seed(...)` then `p.Service.Associate("list", id, new Relationship(...), new EntityReferenceCollection{...})`. Without `WithManyToMany` Associate throws. It also needs to state that the pipeline fires an Associate step only when the Target's entity equals the plugin's TEntity, so both directions need a case. Found through Vela.Testing.xml plus trial.
4. minor - `vela-plugin-authoring/SKILL.md` step 2 no-org stand-in covers "just the needed typed property", not a missing model class. A `List` class was needed for `EntityPluginBase<List>` / `vela add plugin --entity List`, so I hand-wrote it (labelled STAND-IN).
5. minor - no gotcha about domain messages: a contact added to a marketing list through the UI/API may raise AddMember / AddListMembers / AddMemberList, not Associate. `vela-plan-review` does not prompt for it; the reviewer raised it as Required.
6. minor - `vela add test <Name> --kind plugin --entity Contact` on an Associate plugin generates a `PluginContext...WithTarget(new Contact{...}).Execute(...)` body, which is meaningless for Associate (Target is an EntityReference). The skills do not warn that it must be replaced with a pipeline test.
7. minor - `harness-api.md` / `vela-code-review`: the reviewer requires test names verbatim, but the Mono console prints only failing names. Passing names need `-verbose` or `-xml <file>`, which are not documented.
8. minor - the DI identity is ambiguous: the `vela add service` registration line uses `r.GetRequiredService<IOrganizationService>()`, while the skills say to write via `ctx.UserService`. The pack never says which identity DI resolves (the reviewer flagged the same).
9. minor - the review references: `plugin-authoring-api.md` is not bundled with `vela-code-review`, and there is no severity for "Associate matched by entity" (the reviewer inferred Critical).

### Environment (not skill findings)
- `timeout` is not available on macOS zsh (commands re-run without it).
- `vela init` resolved Vela.Plugins 0.29.3 (the pack verified 0.29.1). Above the floor, not a finding.

## Success criteria
1. Canvas records message = Associate, relationship `listcontact_association` and why the handler filters on it: **yes** (docs/vela-builds/contact-marketing-list-stamp.md). The reviewer found Approach/Safeguards inconsistent with the entity-bound registration (Required, unresolved).
2. RED then GREEN (right relationship stamped, other relationship untouched): **yes in the harness**. RED `Total: 6, Errors: 0, Failed: 4` -> GREEN `Total: 6, Errors: 0, Failed: 0` (Mono xunit.console 2.9.2, `-parallel none`). GREEN only after the deviation in finding 1.
3. Build clean of VELA00x: **yes** (`dotnet build ContactStamp.sln -c Release`: 0 Warning(s), 0 Error(s)). `vela-code-review` PASS: **no - BLOCK** (1 Critical, 2 Required).

## Fixes
- none yet (eval run; findings 1-3 need skill/framework work).

## Verdict
**fail.** Blocking findings 1-3: the pack says "match Associate by message" but gives no Vela API, authoring shape or harness recipe for it. The only Vela-expressible registration is entity-bound, which the isolated reviewer blocked as Critical. The next run must re-check: a documented, verified Associate pattern (registration + `vela plan` behaviour on a dev org), the Associate context/harness recipe, and the AddMember-family gotcha.

## Fixes

Framework limit confirmed on the dev org (Associate has one message filter: primary `none`; Vela 0.29.3 binds OnAssociate to the plugin's table; vela plan accepts it). Pack: Associate stories are now recorded as blocked; handler shape and pipeline recipe documented. Upstream gap handed to the owner.
