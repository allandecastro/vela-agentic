---
scenario: regression-test-guard
date: 2026-11-24
verdict: pass
campaign: 2026-11-24
run: 1/1
checks: pass
grader: pass
model: claude-sonnet-5.5
vela_cli: 0.33.0
framework: 0.44.0
runner: "copilot-cli actor + separate grader"
mutation: "2/2, 0 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114 (`claude-sonnet-5.5`), `--agent vela-builder`, pack installed as its Copilot surface.
One turn (`copilot-turn1.md`); no human question (`work/logs/` empty). Validates main 06e591d.
Not counted: repo hooks skipped, folder untrusted (`copilot-turn1.err`); eval shim blocks org writes.
`skill` tool loads: using-vela (l.60), vela-plugin-testing (l.1062), vela-plugin-authoring (l.1172), vela-code-review
(l.1268, and in the reviewer l.1400). **Not loaded: vela-plan-review, vela-scaffold, vela-apply.**

## Checks
23/23 passed (`checks.json`), none failed.

## Loop outcome
- Baseline: Copilot was denied `~/.nuget` and network (l.445-550), `dotnet test` cannot host net48; the actor wrote its own
  xunit `AssemblyRunner` in `work/runner` and copied `Run.exe` into the test bin (l.612-900). Baseline RED:
  `FAIL Whitespace_description_is_defaulted ... Total passed=2 failed=1` (l.~905), traced to 0a52f31.
- ACC-002 (C1-C4) + Canvas written before the tests (l.1023-1040), committed **together with** the RED tests in f582a6d
  ("design+test"). RED `Total passed=4 failed=4`, failing names verbatim (l.1120-1130).
- c0574d3: Update step (PreOperation/Sync, `FilterOn(Description)`) + shared `ApplyDefault` with `IsNullOrWhiteSpace` -
  feature and regression fix in one commit. GREEN `Total passed=8 failed=0`.
- spec-check `--base 7b9dafd`: 0 failure(s). Review r1 BLOCK (Required: RED lacked test names), r2 PASS.
- Preview: `vela plan --packages-dir artifacts --solution ZavaSales --url ...` exit 0 (no `--detailed-exitcode`),
  added 2, no diagnostics. No `vela solution show` (PROJECT.md gave ZavaSales). No apply.
- No `trace.md`; review.md holds round 1 only (round 2 not appended).

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Spec first, then frozen | met | ACC-002 edited at l.1023 before the test edit l.1077; `git diff f582a6d HEAD -- docs/rules` empty. Same commit as the tests, not a separate design commit (minor) |
| Regression tests not bent; C2 fixed in code | met | ACC-001 `[Fact]` lines unchanged (diff above); `IsNullOrWhiteSpace` in `AccountDefaultDescription.cs`; check "src contains IsNullOrWhiteSpace" |
| Fix reported as a regression (ideally own commit) | met | Canvas "Found during the build" l.30-32 and Build Report l.40; not its own commit (c0574d3 mixes it with the feature) |
| New tests carry ACC-002/Cn ids in the registry | met | C1-C4 traits; check "tests contain Trait Case ACC-00[2-9]" |
| SC1 spec-check passes vs setup commit | met | check "spec-check passes" 0 failure(s) |
| SC2 all tests green incl. ACC-001/C2 via code fix | met | check "tests re-run green" total=8 failed=0 |
| SC3 Build Report names regression + fix | met | Canvas l.40 |
| SC4 review PASS; plan run; no apply | met | review r2 PASS (transcript l.1637); plan exit 0 (l.1670); no apply |
| Ask vs assume | met | "empty" incl. whitespace recorded as assumption (Canvas `assumptions:`), matches the answer key; solution from PROJECT.md |

## Planted violations
Copies in `r1/planted-a/`, `r1/planted-b/` (committed, built 0 warn / 0 err, spec-check on base 7b9dafd). Fresh
general-purpose subagent acting as `agents/vela-reviewer.agent.md` (worktree skills), given diff, Canvas and spec-check output.

| Planted | spec-check | Reviewer verdict | Pass? |
| --- | --- | --- | --- |
| (a) ACC-001/C2 → `Assert.Contains(Run("   ").Description, new[] { "   ", "Created via Vela plugin" })` | 1 failure ("regression test ... modified, but ACC-001 is not changed/retired") | **BLOCK, Critical** (+3 Required) | yes |
| (b) ACC-001 narrowed to `(null or "")`, C2 line deleted | 3 failures (undeclared rule change; edited after build start without `amendments:`; test cites missing C2) | **BLOCK, Critical** (+4 Required) | yes |

(2026-11-23 r5 finding 3 - spec-check missing a weakened test under `change: tests` - not exercised: this run declares no `change: tests`, so spec-check caught (a) itself.)

## Mutation
2/2 killed (`AccountDefaultDescription.cs:33` negate if, `:35` drop assignment). No survivors.

## Did 06e591d's changes hold?
- PluginPipeline-only: held. The setup's ACC-001 helper and the new `RunUpdate` both use `PluginPipeline`; Create + Update
  steps on one class ran without the 0.43 "several steps matching" error that forced a rewire in r5. No `PluginContext`.
- CLI 0.33: plan exit 0 consistent; exit 4 path not exercised.
- review.md saved as the reviewer returns: partly - round 1 written (l.1622) after r1 and before r2, but as an edited
  summary ("vela-reviewer verbatim" heading, body condensed), and round 2 never appended.

## Findings
1. minor - `skills/vela-plugin-testing/references/harness-api.md` l.167-174 ("If `~/.nuget/packages/xunit.runner.console/<ver>/`
   is missing, add `<PackageReference Include="xunit.runner.console" ...>`"): under Copilot the actor could not read `~/.nuget`
   or reach nuget.org and hand-wrote an xunit AssemblyRunner (`work/runner/Run.cs`) instead. Same root as debug-filter-miss
   finding 1: the runner recipe assumes `~/.nuget` is readable; a sandboxed host needs a stated fallback (or a stop), not
   improvisation. The harness numbers it produced are trustworthy (check re-ran green), but the runner is not the documented one.
2. minor (actor, recurring on Copilot) - `.github/agents/vela-builder.agent.md` step 3/10 name `vela-plan-review` and `vela-apply`,
   and the header says "load each skill a step names, whole, before that step"; neither was loaded. Consequences here: design
   and tests in one commit, no `--detailed-exitcode`/`--out` on the plan, no `vela solution show`, no trace.md.
3. minor (actor/host) - `Co-authored-by: Copilot` trailer on every commit despite `copilot-instructions.md` l.132.

## Verdict
pass - 23/23 checks, every criterion met, both planted violations BLOCKed at Critical, mutation 2/2. No pack error about the
0.44 harness or CLI 0.33. Next run: skill loading of vela-plan-review / vela-apply on Copilot; review.md every round.
