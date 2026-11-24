---
scenario: account-default-description
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
19/19 passed (`checks.json`). No failed check.

## Loop outcome
- `vela version` → 0.33.0 (trace row 1). Canvas draft → Q1 ("empty"), Q2 (solution) asked one at a time
  (`work/logs/human-questions.md`), answered ZavaSales / zava.
- `vela solution show ZavaSales --json` exit 0 → `{"solution":"ZavaSales","publisherPrefix":"zava"}`; `vela init ZavaSales --prefix Zava
  --publisher-prefix zava --solution ZavaSales` exit 0 (minimal); `vela models --entities account --project src/Zava.Shared/...` exit 0;
  `vela add plugin AccountPlugin ... --stage PreOperation --mode Sync --filtering-attributes Name --handler OnDescriptionDefault` exit 0;
  `vela add test AccountPlugin --kind plugin --entity Account --message Create` inside the test project.
- Commits: Canvas + ACC-001 (0a016af) → scaffold/models (93a8b41) → RED tests (90ffbb4) → handler (41927e0) → Build Report (69ca489).
- RED: Mono xunit.console 2.9.3 `-parallel none`, `Total: 7, Errors: 0, Failed: 4` (C1 x2, C2, C3, actual null/""/whitespace) exit 1.
  GREEN `Total: 7, Errors: 0, Failed: 0, Skipped: 0`. Release build 0 warnings 0 errors.
- spec-check 0 failures. Review: dispatched as subagent type **`vela:vela-reviewer` (the installed plugin copy)**, prompt told it to
  read the worktree `agents/vela-reviewer.agent.md` + `skills/vela-code-review` → PASS, 0 Critical/Required, 3 Nits.
- `dotnet build -c Release` → `artifacts/zava_Zava.Plugins.1.0.0.nupkg`; `vela plan -p ... --solution ZavaSales --detailed-exitcode` exit 8
  (changes pending: create package + 1 step Create/account/20/Sync/[name]). Stopped before apply; Build Report written.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| SC1 `vela init` + `vela add plugin` exit 0, tests in the scaffold `.Tests` project | met | trace rows 5, 7; `tests/Zava.Plugins.Tests/Account/Plugins/AccountPluginTests.cs` |
| SC2 real `EntityPluginBase`/`OnExecute`-era surface, `ctx.Request.Target`, no magic strings | met | `AccountPlugin.cs:9,21,30-33` (`EntityPluginBase<Account>`, `FilterOn(e => e.Name)`, `target.Description`) |
| SC3 test-first RED→GREEN, Mono `-parallel none`, real harness | met | commit 90ffbb4 before 41927e0; RED Failed: 4 / GREEN 7/7; `PluginPipeline` in all tests |
| SC4 build green, no VELA00x | met | checks "build succeeds", "no VELA diagnostics" |
| SC5 null/""/whitespace defaulted; non-empty untouched | met | tests l.35-95 (C1-C4); mutation 2/2 killed |
| SC6 PreOperation, edits Target, no `Service.Update` | met | check "step registered ... PreOperation"; check "src must not contain Service.Update"; `AccountPlugin.cs:19,33` |
| SC7 Canvas with cases + Build Report (harness, analyzers, cases checklist) | met | `docs/features/account-default-description/README.md:30-35` cases, `:81-95` evidence with `[x]` checklist |
| Ask vs assume, one question at a time | met | Q1, Q2 single questions with a proposed default; filter-on-Name gap recorded as assumption (`README.md:41`) |
| Preview on the final package, stop before apply | met | plan exit 8 on the built nupkg (sha256 in Build Report); no apply |

No planted-violation section in the scenario.

## Mutation
2/2 killed (`AccountPlugin.cs:31` negate if, `:33` drop assignment). No survivors.

## Findings against the skills
None blocking. 0.44 harness (`PluginPipeline.Empty().Register<>()`, `Seed`, `ExecutionLog`, `Service.Retrieve<T>(id, cols)`) and
CLI 0.33 flags all worked as the pack teaches; no pack error found.

1. minor (eval/env, not pack text) - the actor dispatched `subagent_type: "vela:vela-reviewer"`, the **installed** plugin agent (an older
   copy under `~/.claude/plugins/cache/vela-agentic/`), instead of a fresh general-purpose subagent as the actor prompt said. Mitigated: the
   prompt told it to read the worktree's `agents/vela-reviewer.agent.md` and skills. `skills/vela-code-review/SKILL.md:67` ("Default -
   `vela-reviewer` agent") names the type, which on a host with the plugin installed resolves to whatever version is installed.

## Verdict
pass - 19/19 checks, every criterion met, 2/2 mutants killed. Next run: confirm the reviewer is dispatched from the pack under test.
