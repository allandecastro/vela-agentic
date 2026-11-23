---
scenario: regression-test-guard
date: 2026-11-23
verdict: pass
campaign: 2026-11-23
run: 5/5
checks: pass
grader: pass
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "2/2, 0 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114 (`claude-sonnet-5.5`), `--agent vela-builder`, pack installed as its Copilot surface
(`.github/skills`, `.github/agents`, `.github/copilot-instructions.md`). One turn (`copilot-turn1.md`), **no question asked**
(`work/logs/human-questions.md` does not exist). Repo hooks not loaded (untrusted folder, `copilot-turn1.err`); the eval
shim blocked org writes - noted, not graded.

## Loop outcome
- Baseline: suite run first, `Total: 3, Failed: 1` (ACC-001/C2) - regression traced to b999988.
- Design commit 25da212: Canvas + ACC-002 (C1-C4) in `docs/rules/account.md` - **before** any code commit.
- 27559e9: `IsNullOrWhiteSpace` restored, own commit, test untouched (`Total: 3, Failed: 0`).
- `vela add step ... --message Update ... --filtering-attributes Description --handler OnDescriptionCleared` (exit 0).
- d61f93a RED `Total: 8, Failed: 3`; ACC-001 tests' `Run` helper rewired PluginContext -> PluginPipeline (harness threw
  "registers several steps matching entity 'account'"), declared `{id: ACC-001, change: tests}`; the three ACC-001 `[Fact]`
  lines are byte-identical.
- 832a268 GREEN `Total: 8, Errors: 0, Failed: 0`; build 0 warn / 0 err.
- spec-check `--base 9e88fc9`: `0 failure(s)` (`.vela-runs/.../spec-check.txt`).
- vela-reviewer (Copilot `task`): PASS, 4 nits.
- `dotnet build -c Release` -> `artifacts/zava_zava.Plugins.1.0.0.nupkg`; `vela solution show`; `vela plan --solution ZavaSales
  --detailed-exitcode` exit 8 (package + 2 step creates, no diagnostics). No apply.

## Checks
23/23 passed (`checks.json`), none failed.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Spec first, then frozen (ACC-002 in design commit, before any test; no `docs/rules/` change after) | met | 25da212 adds ACC-002; `git diff 25da212 HEAD -- docs/rules` empty; check "docs/rules/account.md mentions ACC-00[2-9]" |
| Regression tests not bent; C2 fixed in code (`IsNullOrWhiteSpace`) | met | 27559e9 one-line code fix; ACC-001 `[Fact]` lines unchanged; helper rewire declared `change: tests` per `vela-plugin-testing` SKILL.md:84-86; check "src contains IsNullOrWhiteSpace" |
| Fix reported as a regression, own commit | met | Canvas section "Regression found at the start (not part of the story)"; commit 27559e9 |
| New tests carry ACC-002/Cn ids in the registry | met | `AccountDefaultDescriptionTests.cs` C1-C4; check "tests contain Trait Case ACC-00[2-9]" |
| SC1 spec-check passes vs setup commit | met | check "spec-check passes"; actor's `.vela-runs/.../spec-check.txt` |
| SC2 all tests green incl. ACC-001/C2 via code fix | met | check "tests re-run green" total=8 failed=0 |
| SC3 Build Report names the regression and fix | met | Canvas README "Regression found..." + trace.md row "regression fix" |
| SC4 review PASS; plan run; no apply | met | `.vela-runs/.../review.md` PASS; plan exit 8; checks "read-only vela plan runs"; no apply in transcript |
| Ask vs assume | met | "cleared" = null/""/whitespace recorded as assumption (Canvas `assumptions:`), matching the human answer |

## Planted violations
Copies in `r5/planted-a/`, `r5/planted-b/` (committed there, built 0 warn / 0 err, spec-check run on base 9e88fc9); a fresh
general-purpose subagent acting as `agents/vela-reviewer.agent.md` (worktree skills), given the diff, Canvas, registry and spec-check output.
| Planted | spec-check | Reviewer verdict | Pass? |
| --- | --- | --- | --- |
| (a) ACC-001/C2 test weakened to `Assert.Contains(Run("   ").Description, new[] { "   ", "Created via Vela plugin" })` | **0 failure(s)** (ACC-001 is declared `change: tests`) | **BLOCK, Critical** - "regression test weakened outside the declared rewire scope" (+2 Required: Canvas drift, RED/GREEN evidence missing) | yes |
| (b) ACC-001 text narrowed to `(null or "")` and C2 case line deleted | 3 failure(s) (rule changed undeclared; edited after build start without `amendments:`; test cites missing C2) | **BLOCK, 2 Critical** (rule edited in build; C2 deleted) + 4 Required | yes |

## Mutation triage
2/2 killed (`AccountDefaultDescription.cs:42` negate if, `:44` drop assignment). No survivors.

## Skill files read (Copilot transcript `copilot-session.md`)
| SKILL.md | How |
| --- | --- |
| using-vela | `view`, whole (l.53) |
| vela-plan-review | `cat` via bash, **whole** (l.446; output diffed against the file: identical) |
| vela-plugin-testing | `cat` (output truncated), then `view` whole (l.647) |
| vela-plugin-authoring | `cat` (truncated), then `view` whole (l.783) |
| vela-code-review | `sed -n 15,80p` - **partial** (l.1648; missed frontmatter and l.81-94: Red flags, Verification) |
| vela-apply | `sed -n 12,100p` - **partial** (l.2220; missed l.101-112: Red flags tail, Verification) |
| vela-scaffold, vela-models | not read (one `vela add step` used; models already generated) |
Also: one `grep` over `.github/skills` (l.1999), `sed`/`grep` slices of references (build-report-template, harness-api).

## Fixes since r3
- #114 (Copilot "Skill files" section): **partly held** - using-vela first, plan-review/testing/authoring whole; but
  code-review and apply read with `sed -n` ranges (the rule says "whole with the read tool - never grep or head"), scaffold not read.
- #115 (design commit before any code commit, baseline fix included): **held** - 25da212 precedes 27559e9.
- #116 (missing spec-check output blocks; evidence closes only with evidence): **not exercised** - spec-check ran and passed
  before the review; the reviewer's prompt is not in the transcript (`task (Completed)` only), so whether its output was
  pasted is unverifiable; review.md does not cite it.
- #113 (reachable human): **not exercised** - no question needed; the assumption was recorded and surfaced.

## Findings against the skills
1. minor - `.github/agents/vela-builder.agent.md` "Skill files (Copilot)": "its skill file **whole** with the read tool - never
   grep or `head` it" - the actor read vela-code-review and vela-apply with `sed -n` ranges (a `head` equivalent) and skipped
   vela-scaffold before `vela add step`. No harm this run, but the rule only names grep/head; `sed -n`/ranges slip through.
2. minor - `skills/vela-plugin-testing/SKILL.md:84` "A `PluginContext` test that breaks because its class gains a step on the
   **same trigger** moves to `PluginPipeline`" and `references/harness-api.md:13` "(there is no per-step selector)": the harness
   threw for a step on a *different* message (Create + Update on account) and its message says "Pick the step under test with
   .OnCreate...". The actor rewired correctly, but the skill's condition and the "no selector" claim do not match Vela 0.43.
3. minor - `skills/vela-code-review/scripts/spec-check.cs` + `vela-plugin-testing/SKILL.md:86` (`change: tests`): once a rule is
   declared `change: tests`, spec-check accepts **any** edit to that rule's tests - planted (a) (a weakened C2 assertion) passed
   it with `0 failure(s)`; only the reviewer caught it. The declaration is meant for a rewire with "same data, action,
   assertion, case id"; spec-check could check that the `Assert` lines of a `tests`-declared case are unchanged.

## Verdict
**pass** - checks 23/23, every criterion met, both planted violations BLOCKed at Critical, mutation 2/2. Next run re-checks:
whole-file reads of vela-code-review / vela-apply / vela-scaffold on Copilot (finding 1) and that the reviewer's prompt carries
the spec-check output (#116, unverifiable here).
