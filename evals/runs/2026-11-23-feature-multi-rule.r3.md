---
scenario: feature-multi-rule
date: 2026-11-23
verdict: pass
campaign: 2026-11-23
run: 3/3
checks: pass
grader: pass
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "19/25, 4 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114 (`claude-sonnet-5.5`), pack installed as its Copilot surface
(`.github/skills`, `.github/agents`, `.github/copilot-instructions.md`), `--agent vela-builder`. Repo hooks were
not loaded (untrusted folder). The eval shim blocked org writes. Neither counts against the run.

## Loop outcome
- INTAKE/CHALLENGE: one batch of 5 numbered questions before any code (`logs/human-questions.md` Q1). Q4 asks for the
  **roles** and the **denied/out-of-scope read outcome** (a/b/c). PR #112 (always a numbered question) **held**; r1/r2 failed here.
- SCAFFOLD/MODEL: branch `feature/website-https`. `vela models --roles Salesperson` and `--verify` exit 0. The
  rules + Canvas commit (e25f2ba) comes before the code. `vela add step` x2 and `vela add plugin`.
- RED: `Total: 23, Failed: 12`, then after the ACC-001 tests were moved onto PluginPipeline, `Total: 25, Failed: 10`, with the
  10 names in the trace. GREEN: `Total: 25, Failed: 0`. After the review fix: `Total: 27, Failed: 0` (mono xunit, `-parallel none`).
- VERIFY: `dotnet build -c Release` gave 0 warnings and 0 errors. spec-check first failed 3 times (ACC-001 tests rewired), then passed with 0 failures once `change: tests` was declared.
- REVIEW: isolated `vela-reviewer`. Round 1 returned BLOCK with 3 Required findings (RED names, magic-string retrieve, `://` in query). All were fixed and round 2 (scoped) returned PASS.
- PREVIEW: rebuilt the final package, then ran `vela plan -p artifacts/zava_zava.Plugins.1.0.0.nupkg --solution ZavaSales --detailed-exitcode`. Exit 8: added 4 (package + 4 steps), removed 0, changed 0.
- APPLY: not run. Build Report `status: awaiting-apply`.

## Checks
22/22 passed (`checks.json`), including spec-check (0 failures), build, no VELA diagnostics, 27 tests green, plan
creates only authored steps.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| One story, two rules, one Canvas, one branch | met | `docs/features/website-https-contact-default/README.md:16-19` declares ACC-002 (add) and CON-001 (add), each with its own cases (`docs/rules/account.md`, `contact.md`); single branch `feature/website-https` |
| Distinct, unused ids | met | ACC-001 was taken, so the new account rule is ACC-002. CON-001 is the first contact rule (check `docs/rules/contact.md mentions CON-`) |
| Dependency stated | met | CON-001/C10 "Given an account created through the pipeline with http... (ACC-002 applied first)". C11 states "copied as stored". The Then line says "as stored" |
| Grilled up front, both rules | met | Q1 (items 1-2 account, 3-5 contact) logged at session l.479, before the first code at l.1022 |
| Roles + denied outcome asked (r1/r2 regression) | met | Q1 item 4. Answer "Salesperson" is used in tests C8/C9 via the generated `Roles` class. The denied outcome falls back to the default and is recorded under `assumptions:` |
| No layer split; RED then green | met | session l.1906/2074 RED (named failures), l.2105 implement, then GREEN. Tests and implementation are per story, with no separate "tests" task (see finding 2 on commit granularity) |
| Existing rules untouched; spec-check clean | met | ACC-001 text unchanged. The test rewire is declared `{id: ACC-001, change: tests}` and the C9/C10 additions are listed under `amendments:`. `spec-check: 0 failure(s)` |
| One review PASS | met | round 2 PASS (session l.3821) |
| Plan run, no apply | met | exit 8 on the final package (l.3929). There is no `vela apply` in the transcript |

## Planted-violation check
None in this scenario.

## Mutation triage (19/25; 6 survivors)
| # | Mutant | Verdict | Why |
| --- | --- | --- | --- |
| 1 | `AccountDefaultDescription.cs:44` `text.Length > 0` → `>= 0` | **missing test** | Input `"://zava.com"` (empty scheme) now throws `IndexOutOfRange` on `text[0]`. Before the mutant it got `https://` in front, as ACC-002 says ("a Website without any scheme gets https://"). The round-2 reviewer named this input as a nit, but no case was added for it |
| 2 | `:44` `c=='.' \|\| c=='-'` → `c=='.' && c=='-'` (drops `-`) | **missing test** | A scheme containing `-` is now read as "no scheme" and gets `https://` in front, against ACC-002 "another scheme ... left as entered". The only other-scheme case is C8 `ftp://`, which is letters only |
| 3 | `:44` `c=='+' \|\| c=='.'` → `&&` (drops `+` and `.`) | **missing test** | Same as #2: no case has a scheme with `+` or `.` (for example `svn+ssh://`) |
| 4 | `:44` `c=='.'` → `c!='.'` | **missing test** | `/`, `?` and `=` are now accepted in a scheme. C9 still passes only because its host has a dot (`zava.com/?next=http`). `localhost/?next=http://x` would be left untouched, against the C9 rule ("a :// only in the query is not a scheme") |
| 5 | `:56` `schemeEnd < 0` → `<= 0` | equivalent | When `schemeEnd == 0`, `IsScheme("")` is already false, so both forms take the prefix branch |
| 6 | `ContactWebsitePlugin.cs:28` `parent == null \|\| parent.LogicalName != account` → `&&` | equivalent | A null parent never reaches the handler because the step filters on `ParentCustomerId` (C6 asserts an empty `ExecutionLog`). A contact parent now gets `Retrieve<Account>` on a contact id, which faults and is caught, so the outcome is the same as before |

All 4 missing tests come from the `IsScheme` grammar that the review fix introduced (commit 853c01d). It got one case (C9), but its character classes and empty-scheme boundary got none.

## Findings
1. minor - `skills/vela-plugin-testing/SKILL.md:29` says "each **edge** (empty / null / invalid / boundary)", and l.66-71 cover RED cases. Neither applies to a helper added by a **review-driven fix**. The reviewer proposed a scheme grammar (letter, then letters/digits/`+`/`.`/`-`). The actor added one case (C9) and shipped the grammar without cases for `+ . -` or an empty scheme. That produced 4 surviving mutants. `vela-code-review` round 2 noticed `://x` and filed it as a nit, which does not block. Fix: the review skill could require that a fix introducing new branching logic adds its edge cases as an amendment.
2. minor - `skills/vela-plugin-testing/SKILL.md:71` says "**Commit the RED tests alone** (provable in git)". The actor committed the tests and the implementation together (aadd353 "feat: ..."), so RED shows only in the transcript and the trace, not in git. The review fix (853c01d) also added C9/C10 together with the code, without a RED run first: the "Bug fixed: the failing repro test (RED) now passes" evidence in `AGENTS.md` is missing for that fix. Neither the reviewer nor the build loop caught either point. This is a compliance gap on the Copilot surface; the rule text is clear.

## Verdict
**Pass.** Checks are 22/22 and every grader criterion is met. The PR #112 change held: roles and the denied-read outcome were asked as numbered question 4 and the answers flowed into C8/C9 with `Roles.Salesperson`. The mutation score is 19/25, with 4 missing tests, all in the review-added `IsScheme` helper. The next run should re-check whether a review-driven fix gets its own RED test, and whether that fix's edge cases are covered.
