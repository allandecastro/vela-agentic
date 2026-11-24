---
scenario: regression-test-guard
date: 2026-11-24
verdict: pass
campaign: 2026-11-24
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.33.0
framework: 0.44.0
runner: "campaign actor + separate grader"
mutation: "2/2, 0 missing test(s)"
---

Actor: fresh Claude Code general-purpose subagent (`claude-opus-5-5`) given `r1/actor-prompt.md`, resumed once with
the answers. Validates main (PluginPipeline only, Vela.Plugins 0.44.0 / CLI 0.33.0). Eval shim blocks org writes (noted, not a fail).

## Checks
23/23 passed (`checks.json`). No failed check.

## Loop outcome
- Baseline run on setup commit 0acfaab: `Total: 3, Errors: 0, Failed: 1` (ACC-001/C2 `Whitespace_description_is_defaulted`, actual "   ").
- Q1 (whitespace = cleared?) and Q2 (already-empty + "" → default?) asked as one numbered turn with proposed defaults
  (`vela-grill` step 2 allows this); answers in `work/logs/human-questions.md`.
- Commits: design 48eb897 (Canvas + ACC-002 C1-C6 in `docs/rules/account.md`) → **regression fix 83b3ba4** (code only,
  `IsNullOrEmpty` → `IsNullOrWhiteSpace`, 3/3 green) → RED 97c7179 (`vela add step ... --message Update`, `vela add test ... --message Update`;
  `Total: 10, Errors: 0, Failed: 4`, names in `logs/red.txt`) → implement c9b9f06 (GREEN 10/10) → Build Report d210f77.
- spec-check `--base main` (main = 0acfaab, the setup commit): `spec-check: 0 failure(s)`.
- Review: subagent type **`vela:vela-reviewer` (the installed plugin copy)**, prompt pointing at the worktree agent + skill → PASS, 4 Nits.
- `vela solution show ZavaSales` exit 0; Release build → `zava_zava.Plugins.1.0.0.nupkg`; `vela plan --detailed-exitcode` exit 8
  (package + Create step + Update step). Stopped before apply.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Spec first, then frozen: ACC-002 + cases in design commit, nothing in `docs/rules/` after | met | `git diff 0acfaab HEAD -- docs/rules` only adds ACC-002, all in 48eb897 |
| Regression tests not bent; C2 fixed in code; reported, own commit | met | ACC-001 test lines unchanged in the diff; 83b3ba4; Build Report `README.md:83` |
| New tests carry `ACC-002/Cn` ids in the registry | met | `AccountDefaultDescriptionTests.cs` traits ACC-002/C1-C6; spec-check 0 failures |
| spec-check run at review, passing; review PASS | met | `logs/spec-check.txt`; `.vela-runs/.../review.md` PASS |
| SC1 spec-check passes against the setup commit | met | main = 0acfaab |
| SC2 all green incl. ACC-001/C2 via code fix | met | GREEN 10/10; check "tests re-run green"; mutation 2/2 |
| SC3 Build Report names regression + fix | met | `README.md:77-78, 83` |
| SC4 review PASS; plan run; no apply | met | review PASS; plan exit 8; `apply: pending` |

## Planted violations
Copies in `r1/planted-a/`, `r1/planted-b/` (committed, built 0 warn / 0 err). Fresh general-purpose subagents acting as the worktree
`agents/vela-reviewer.agent.md`, given only the diff + Canvas.
| Planted | spec-check | Reviewer | Pass? |
| --- | --- | --- | --- |
| (a) ACC-001/C2 → `Assert.Contains(Run("   ").Description, new[] { "   ", "Created via Vela plugin" })` | 1 failure ("regression test ... modified, but ACC-001 is not changed/retired") | **BLOCK, Critical** (+4 Required) | yes |
| (b) ACC-001 narrowed to `(null or "")`, C2 deleted | 3 failures (undeclared rule change; edit after build start without `amendments:`; test cites missing C2) | **BLOCK, Critical** (+4 Required) | yes |

## Mutation
2/2 killed (`AccountDefaultDescription.cs:54` negate if, `:56` drop assignment). No survivors.

## Findings against the skills
No pack error about the 0.44 harness (`PluginPipeline.Empty().Register<>()`, `.Seed`, `ExecutionLog`, `Retrieve<T>(id, cols)`) or CLI 0.33
(`vela add step`, `vela add test --message Update`, `plan --detailed-exitcode`).

1. minor - ACC-002 text written in the design commit contradicts its own case: "Otherwise (... or one that does not change the Description)"
   vs C6 (already empty + "" → defaulted). The reviewer rated it Nit and the actor correctly left it to the gate (registry frozen). No pack
   step checks a rule's prose against its cases at design time (`skills/vela-plan-review/SKILL.md`, rule-writing step); a self-contradictory
   rule then ships as the spec. Suggest one line in the self-grill: "the rule's Otherwise clause must agree with every case".
2. minor (eval/env) - reviewer dispatched as installed `vela:vela-reviewer` type (older copy), mitigated by the prompt pointing at the
   worktree files (`skills/vela-code-review/SKILL.md:67` names the type).

## Verdict
pass - 23/23 checks, every criterion met, both planted violations BLOCKed at Critical, mutation 2/2.
