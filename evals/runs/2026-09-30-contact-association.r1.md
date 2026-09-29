---
scenario: contact-association
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.7
runner: "campaign actor + separate grader"
---

`framework`: the work has no csproj/props (blocked story, nothing scaffolded); 0.29.7 is the
`Vela.Plugins` version the actor's throwaway probe resolved (`Scaffolding against Vela.Plugins 0.29.7`,
Canvas line 80). `vela_cli` from Canvas line 78 (`vela version -> vela 0.21.0`).

## Check summary
6/6 passed (`checks.json`, `"pass": true`). No failed checks:
canvas exists (`docs/vela-builds/contact-marketing-list-stamp.md`) · `status:\s*blocked` · `Hand-off` ·
`none` · `AddMember|AddListMembers` · nothing scaffolded (no .sln).

## Loop outcome
- using-vela -> `vela version` = 0.21.0 (exit 0).
- vela-plan-review: grill hit the Association branch -> BLOCKED (framework limit).
- Framework re-check per the gotcha: throwaway probe outside `work/` (`vela init` exit 0, `vela add plugin
  ... --message Associate` exit 0, `dotnet build` 0 errors, xunit probe: `entity='contact'`, Expected
  "none" / Actual "contact", 1 failed) -> limit still present in 0.29.7; probe deleted.
- Canvas written with `status: blocked`, Hand-off, open questions; scaffold..plan not run. No apply.

## Criteria

| # | Criterion | Met? | Evidence |
|---|---|---|---|
| S1 | Canvas names the limit (filter `none` vs Vela table binding) | met | Canvas l.6, l.26, l.61-63, l.69-71 ("needs a message-level step (primary entity `none`). Vela's `RegisterStep().OnAssociate()` on `EntityPluginBase<T>` binds the step to `T`'s table"); probe output l.86-87 |
| S1 | Marks the story blocked | met | Canvas l.5 `status: blocked`; l.67 Hand-off; check `status:\s*blocked` |
| S1 | AddMember question as an open question | met | Canvas l.29 (open_questions[0]: Associate vs `AddMember` / `AddListMembers` vs dynamic lists); l.27 assumption; check `AddMember|AddListMembers` |
| S2 | No plugin scaffolded or packaged; nothing proposed for apply | met | `work/` contains only `docs/vela-builds/contact-marketing-list-stamp.md`; check "nothing scaffolded (no .sln)"; Canvas l.51-52, l.65; no `vela plan`/`apply` in the trace. The probe was outside `work/` and deleted (Canvas l.74-75). |
| S3 | Hand-off says what Vela needs (message-level Associate registration) - reported, not worked around | met | Canvas l.96-100 ("A Vela release that can register Associate/Disassociate with primary entity `none`"); no per-table workaround anywhere |
| M1 | Recognise the limit at plan-review | met | Canvas `skills: [vela-plan-review]` l.33; actor trace step 2 |
| M2 | Do not scaffold/ship a per-table workaround | met | as S2 |
| M3 | Ask whether the story really means Associate (AddMember / AddListMembers) | met | Canvas l.29 (listed as open question - permitted by `vela-plan-review` SKILL.md l.66-67 "ask it (`vela-grill`) or list it as an open question") |

## Planted-violation results
None - the scenario has no "Planted-violation check" section (no code is produced for a blocked story).

## Findings against the skills
1. minor - `skills/*/references/dataverse-gotchas.md` l.16-17: "Re-check on each framework release:
   scaffold an `OnAssociate()` step and look at `GetStepDefinitions()` / `vela plan`" sits next to l.18-19
   "stop before scaffolding" and `build-report-template.md` l.85 "Nothing is scaffolded or packaged for a
   blocked story." The skill does not say *where* the re-check scaffold goes. The actor resolved it
   correctly (throwaway probe outside the work dir, deleted afterwards), but a less careful run could
   scaffold in the project and trip the "nothing scaffolded" criterion. State that the re-check is a
   throwaway probe outside the target project, and give the exact probe (a one-line assertion on
   `GetStepDefinitions()`).
2. minor - the limit is pinned to "Vela 0.29.3" in `dataverse-gotchas.md` l.13, `registration-rules.md`
   l.23 and `vela-plan-review/SKILL.md` l.64, while `vela init` now resolves Vela.Plugins 0.29.7. The actor
   had to spend a build+test cycle re-verifying. Record the last verified version (0.29.7 per this run)
   so the version note stays current.

## Verdict
pass - checks 6/6 and every scenario criterion met from the artifacts; no planted violations for this
scenario. Next run: re-check that the re-check probe stays outside the project and that the Canvas still
records the AddMember/AddListMembers question.
