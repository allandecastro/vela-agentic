---
scenario: creditlimit-threshold-role
date: 2026-11-15
verdict: pass
campaign: 2026-11-15
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.29.0
framework: 0.42.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **26/26 passed**, no failed check. Note: the role check was corrected before this run so that it
accepts `roletemplateid` / `Roles.XTemplateId` (Vela 0.42 system-role path) beside `parentrootroleid` / `Roles.XId`.

## Loop outcome
- intake: `vela version` -> 0.29.0, which matches cli-surface (trace.md #1).
- challenge: two read-only role probes outside the project (`vela models --roles ... --out probe/probe2`, exit 0).
  The human was asked 5 questions, one at a time (logs/human-questions.md Q1-Q5). The Canvas, rule ACC-002 and
  ADR 0001 were committed before any code (690752c).
- model: `vela models --entities ...,role,systemuserroles,teamroles,teammembership --roles "Sales Manager,System Administrator,Salesperson" --project src/zava.Shared/...` exit 0 (6f1dd83).
- scaffold: `vela add step` x2, `vela add service CreditLimitApprover`, `vela add test` (48eee82).
- RED (3bb859a): `Total: 19, Failed: 5` (C1, C6 x2, C7, C8). Mutations proved the cases that already passed at RED.
- GREEN: `Total: 20, Failed: 0` (Mono xunit console, `-parallel none`). The evaluator re-ran the suite: 20/0.
- verify: Release build 0 warnings, 0 errors, 0 VELA. spec-check 0 failures. `vela models --verify --roles` exit 0.
- review: isolated vela-reviewer, PASS (0 Critical, 0 Required, 6 Nits) (.vela-runs/.../review.md).
- preview: `vela solution show ZavaSales --json` exit 0. `vela plan ... --solution ZavaSales --detailed-exitcode` exit 8 (changes: package + 3 steps).
- gate: Build Report written, status `awaiting-apply`. No apply.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| S1 | Code is justified (a value condition that privileges cannot express) | met (behaviour) | A plugin was built for a value threshold, and the role privileges were read first (trace #2, #11). The Canvas does not write down *why* code was chosen over configuration (see finding 1). |
| S2 | Generated roles: `vela models --roles` into Shared; tests use `.Role(Roles.XName, Roles.XId, ...)` | met | trace #15. `src/zava.Shared/Models/Generated/Roles.cs`. Tests at AccountCreditLimitApprovalTests.cs:33-35 use the system-role form with `TemplateId`. |
| S3 | Root id / template id check; team roles count | met | CreditLimitApprover.cs:29,40-41,48-50: `roletemplateid` in {`Roles.SalesManagerTemplateId`, `Roles.SystemAdministratorTemplateId`}, both directly and through teammembership->teamroles. Per evaluator note (1), this is the correct path for system roles in Vela 0.42. |
| S4 | Sync PreVal/PreOp on Create + Update of account, `FilterOn(creditlimit)` | met | AccountDefaultDescription.cs:26-39. checks "step registered: Create/Update ... creditlimit". |
| S5 | French message in the project messages source | met | src/zava.Plugins/Messages.cs:24 holds the exact human text in LCID 1036. The scenario's `Localization/Messages.cs` path predates the 0.29 layout. |
| S6 | Tests RED first, each with its case id | met (minor) | RED 3bb859a before the implementation in 2e0e2c9. Every test has `Trait("Case", "ACC-002/Cn")`. One extra C1 read-denied test was added after the implementation (1b928d9). It is recorded in the Sync log and was shown failing by mutation. |
| C1 | Roles generated, tests use them, no hand-built role except one named for a missing privilege | met | The only hand-built role is "Account creator without role read" (tests:50-52), which is named for the privilege it lacks. |
| C2 | Root/template id check; team-role case and child-BU case tested | met | C3 (`SalesBu`, a child BU, tests:125-132) and C4 (team in `OtherBu`, tests:134-141). Canvas acceptance cases C3/C4. |
| C3 | Steps on Create + Update filtered on creditlimit; spec-check passes; review PASS; `vela plan` run; no apply | met | checks (steps, spec-check, read-only plan). review.md PASS. plan.json, exit 8. Canvas `apply: pending`. |
| Q | One question at a time; asks rather than assumes | met | human-questions.md has Q1-Q5, each a single question. The two items deferred to "defaults" (currency, message source) are recorded as assumptions in the Canvas (README.md:39-40). Solution/prefix came from PROJECT.md and were confirmed with `vela solution show`, so nothing needed asking. |

## Planted-violation results
Each copy is the actor's HEAD (git archive) plus the violation. Both build green with 0 VELA. Each was reviewed by a fresh general-purpose subagent acting as `agents/vela-reviewer.agent.md`, reading the skills from the repo, and given only the diff and the Canvas.

| Violation | Copy | Expected | Verdict | Result |
|---|---|---|---|---|
| (a) role check on `systemuserroles.roleid` / `teamroles.roleid` against `Roles.SalesManagerId` (no root/template match) | planted-a/ | BLOCK, Required | **BLOCK**, Critical (BU-copy gotcha; breaks C3/C4/C5/C12 on a live org), plus Critical spec drift, plus Required missing evidence | pass |
| (b) Sales Manager / System Administrator template GUIDs written by hand in the plugin service | planted-b/ | BLOCK, Required | **BLOCK**, Required (review-checklist "role GUID ... written by hand instead of the generated Roles"), plus Required missing evidence | pass |

## Findings against the skills
1. minor - `skills/vela-plan-review/SKILL.md` step 0 says "A plugin only for what privileges cannot express (a condition on values or on other rows)". This settles the code-vs-configuration choice. It does not ask for the justification to be recorded in the Canvas when code *is* chosen. The actor chose correctly, but the Canvas (A - Approach) has no line saying why role privileges cannot express this rule, so the decision cannot be traced in the artifact. Suggest one Canvas line (e.g. under A or decisions) whenever step 0 resolves to code.
2. minor - The test-first rule (AGENTS.md "Test-first is mandatory") gives no guidance for a test that proves an ADR or security-context decision taken at the plan gate. In this run, ADR 0001 required "proven by a `WithSecurity` test", but the read-denied case was not a declared acceptance case. It was written after GREEN and proven by mutation (Sync log). `vela-plan-review` / `vela-test-harness` could have the plan gate turn each ADR-mandated proof into a declared case, so that it is RED first.
3. Observation (Vela gap, not a skill defect - for the user to relay): two Create/PreOperation/Sync steps on one plugin class (one class per table) cannot be driven by `PluginContext`. The actor had to move the ACC-001 tests to `PluginPipeline`. `vela plan` also reports a rank-1 execution-order collision for the two steps.
4. Observation (scenario text, not the pack): "the message in French in `Localization/Messages.cs`" and "`parentrootroleid` ... to `Roles.SalesManagerId`" predate Vela 0.29 / 0.42. The 0.42 layout is the generated `Messages.cs`, and system roles are matched on `roletemplateid` / `Roles.XTemplateId`. The scenario file should be updated.

No blocker findings.

## Verdict
**pass**. Checks are 26/26 and every criterion is met. Both planted violations were BLOCKed at Required or higher. The next run should re-check whether the Canvas records the code-vs-configuration justification (finding 1) and whether ADR-mandated proofs are declared as RED-first cases (finding 2).
