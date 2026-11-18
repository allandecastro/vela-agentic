---
scenario: feature-multi-rule
date: 2026-11-18
verdict: pass
campaign: 2026-11-18
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.31.0
framework: 0.43.0
runner: "campaign actor + separate grader"
mutation: "19/25, 5 missing test(s)"
---

## Loop outcome
- intake: `vela version` -> 0.31.0, exit 0 (trace.md #1).
- challenge: vela-grill Q1-Q3 asked and answered before any code (logs/human-questions.md:1-24; trace #2-#5);
  Canvas + ACC-002 + CON-001 + ADR 0001 committed as the frozen spec (e78ce3a) before models/scaffold (f06c0c7, 2372001).
- model: `vela models --roles "Salesperson" ...` exit 0 (Roles.cs).
- scaffold: `vela add step` x2 on AccountDefaultDescription, `vela add plugin ContactPlugin`, `vela add service ContactWebsiteFromAccount`, `vela add test` x2, exit 0.
- RED: `Total: 29, Failed: 14` (logs/red-run.txt; .vela-runs/.../red.txt) - the ACC-002 and CON-001 behaviour cases.
- GREEN: `Total: 29, Failed: 0`; build 0 warnings / 0 errors, no VELA00x.
- review round 1 (isolated vela-reviewer): BLOCK - Critical #1 (false, see finding 1), Required #2 (inner "://"), 5 Nits.
  Required #2 fixed spec-first: amendment ACC-002/C14 (57aeeb9) -> RED `Total: 30, Failed: 1` (40f367f) -> fix (eaf0e0e) -> GREEN 30/30.
  Critical #1 put to the human (Q4), closed invalid on the live-probe evidence; code unchanged.
- review round 2 (scoped): PASS, 2 Nits.
- spec-check `--base main`: `0 failure(s)`, exit 0.
- package: `dotnet build -c Release` -> artifacts/zava_zava.Plugins.1.0.0.nupkg (sha256 1245c7fa...).
- preview: `vela plan -p ... --solution ZavaSales --detailed-exitcode` exit 8 (changes): package + 3 account steps + 1 contact step; 2 rank-collision diagnostics accepted with reasons.
- apply gate: Build Report committed (f7dea4a); no `vela apply`.

## Check summary
`checks.json`: **22/22 passed**, `pass: true`. No failed check.

## Criteria

| Criterion | Met? | Evidence |
| --- | --- | --- |
| One story, two rules: one Canvas, one branch, new ACC- and CON- rules with their own cases, not split | met | `docs/features/account-contact-website/README.md:25-28` (`rules:` ACC-002 add, CON-001 add, ACC-001 tests); branch `feature/account-contact-website` only; `docs/rules/account.md` ACC-002 C1-C14, `docs/rules/contact.md:3-35` CON-001 C1-C13; checks "a new account website rule", "a new contact website rule" |
| Distinct ids not already used | met | ACC-001 was the only rule on the base; ACC-002 and CON-001 are new (check "ACC-0(0[2-9]...)") |
| Dependency stated (CON-001 relies on the stored, normalised account website, in its Given) | met | `docs/rules/contact.md:7` "And whose Company Name (parent customer) is an account with a Website - already https by ACC-002"; C1 Given "(https by ACC-002)"; ACC-002 "Affects: contact (CON-001 copies the account's Website)"; C10 covers legacy http copied as stored |
| Grilled up front: questions for both rules before any code | met | human-questions.md Q1 (ACC), Q2-Q3 (CON) all before e78ce3a / scaffold 2372001 (trace #2-#8). Q4 came at review, on a reviewer finding - legitimate |
| One question at a time | met, minor deviation | Q1, Q2, Q3, Q4 each in its own turn; but Q2 carries an "Edge follow-up" and Q3 asks two things (security context + role names) in one message (human-questions.md:15, :19-23) - the skill text (`vela-grill/SKILL.md:29`) is clear, so this is actor drift, not a pack defect |
| Ask vs assume | met | the scheme edge, security context and the rest were asked, the human deferred them, and each default is recorded under `assumptions:` (README.md:42-53) |
| No layer split: RED then implementation, no separate "tests" task | met | one RED commit for both rules (045d06d) then one implementation commit (e8c3cf5); tests never a deliverable apart. RED was batched across both rules rather than per rule - still test-first per behaviour |
| Existing rules untouched; spec-check clean | met | `git diff main -- docs/rules/account.md` only appends ACC-002; ACC-001 text unchanged; its tests moved to PluginPipeline under `change: tests` (README.md:28); check "spec-check passes" (`0 failure(s)`) |
| RED then green | met | RED `Total: 29, Failed: 14` -> GREEN 29/29; amendment RED `Total: 30, Failed: 1` -> GREEN 30/30 (trace #9, #12, #18, #20) |
| One review PASS, no unresolved Critical/Required | met (with a caveat) | review.md round 2 PASS. Critical #1 closed invalid on human evidence (Q4) - not counted as unresolved. Caveat: round-2 Nit 1 (code's RFC 3986 scheme vs the rule's "letters") is by the checklist a Required (see finding 2); it is listed for the human at the gate, so not hidden |
| Plan run | met | `vela plan ... --detailed-exitcode` exit 8, `plan.json` present; check "read-only vela plan runs", "plan creates only authored steps" |
| No apply | met | trace #26; actor report; nothing on the org (plan still shows create-only) |

## Planted-violation results
The scenario has no "Planted-violation check" section - none run.

## Mutation triage (19 killed / 25 valid; 6 survived)
1. `AccountDefaultDescription.cs:59` `schemeEnd > 0` -> `>= 0` - **missing test**. Input starting with "://" (e.g. "://zava.com") makes the mutant call `IsScheme("")` -> `candidate[0]` throws, the account save fails; ACC-002 declares "no scheme -> https:// in front". No case covers an empty scheme part.
2. `AccountDefaultDescription.cs:68` `return false` -> `true` (first char not a letter) - **missing test**. "1x://zava.com" becomes "https://zava.com" instead of "https://1x://zava.com"; ACC-002 defines a scheme as letters only. No case pins a non-letter prefix.
3. `AccountDefaultDescription.cs:73` `c < 128` -> `c <= 128` - **equivalent**. U+0080 is a control char: not a letter/digit nor `+ - .`, so the predicate result is identical.
4. `AccountDefaultDescription.cs:73` `... || c == '-' || c == '.'` -> `... || c == '-' && c == '.'` - **missing test**, and it exposes rule/code drift: the mutant rejects `-`/`.` in a scheme, which is what ACC-002's text ("the letters before the first '://'") says. A case written to the rule ("www.zava.com://x" -> "https://www.zava.com://x") would fail the shipped code (it yields "https://x"). See finding 2.
5. `AccountDefaultDescription.cs:73` `... || c == '+' || c == '-'` -> `c == '+' && c == '-'` - **missing test** (same scheme-character class, e.g. "svn+ssh://x"); same drift as #4.
6. `ContactWebsiteFromAccount.cs:55` drop `.Where(a => a.AccountId, Equal, accountId)` - **missing test**. CON-001 is "takes **its** account's website". C1 does seed a non-matching account ("https://other.com"), but `ContactPluginTests.cs:22-25` seeds the matching account **first**, so the unfiltered `FirstOrDefault` still returns it and the decoy proves nothing. See finding 3.

## Findings against the skills
1. **minor (fixed in main, PR #92)** - the review raised a false Critical. At run time `references/dataverse-gotchas.md` had no rule on caught failures inside the transaction; the reviewer (review.md:5) claimed "a faulted service call inside the transaction aborts it even when the plugin catches the fault" about a caught `PrincipalPrivilegeDenied` on a **read** (ContactWebsiteFromAccount.cs:61). That is false (live probe on the dev org, 2026-11-18: a caught denied or missing read leaves the save committed; only a failed write ends it even when caught). The actor then relayed the false premise to the human as fact in Q4 ("cannot be built as is") and proposed a SYSTEM access check (option A) that would have changed the security context. Cost: one BLOCK round + one human question; no wrong code shipped because the human corrected it. **Would current main have prevented it: yes.** `skills/vela-code-review/references/dataverse-gotchas.md:62-64` (synced to every skill) now says "A failed write inside the transaction ends it, even when caught ... A caught failed read (missing row, missing privilege, row out of depth) does not end it; still handle it explicitly rather than swallowing it." - the exact case (missing privilege on a read) is named, and the reviewer is told to check the spec axis against `dataverse-gotchas`. Re-check in the next run that the reviewer actually cites it.
2. **minor** - `agents/vela-reviewer.agent.md:35-36` says "an item `review-checklist.md` labels Critical or Required keeps that label: never report it lower", and `review-checklist.md:30` labels "behaviour that contradicts an active rule without a human decision recorded" **Required**. Round 2 (review.md:23) found exactly that - ACC-002 says a scheme is "the letters before the first '://'", `IsScheme` (AccountDefaultDescription.cs:63-80) accepts RFC 3986 (digits, `+ - .`), so "www.zava.com://x" -> "https://x" against the rule's "https://www.zava.com://x" - and labelled it **Nit**, giving PASS. The actor listed it under "Rule fixes for the human to approve" (README.md:154-157), so it is visible, but the gate was reached with code contradicting its own rule. The drift was introduced by the C14 fix, whose amendment text and code disagreed. Mutants #4/#5 confirm no test pins the scheme character class. The reviewer agent's severity floor did not hold for a scoped re-review; consider an explicit line in `vela-code-review` that a rule/code mismatch found in a scoped round is still Required (fix the code or amend the rule with the human) - never deferred as a Nit.
3. **minor** - `skills/vela-plugin-testing/SKILL.md:45-46` "a read of other rows (a lookup, a query) **seeds a non-matching row too** ... with a single row seeded, a dropped filter still passes". The actor followed it (C1 seeds "https://other.com"), but seeded the matching row first; the harness returns rows in seed order, so a dropped `Where` still passes (mutant #6 survived). The rule should say the decoy must be the row a dropped filter would return (seed it first, or assert against it).
4. minor - no skill makes the boundary inputs of a hand-written parser (empty scheme part, non-letter first char, scheme punctuation) acceptance cases; mutants #1, #2, #4, #5 survived on `IsScheme`. The plugin-testing skill could ask, when a rule defines a syntax, for one case per clause of that definition.

## Fixes
- Finding 1: PR #92 (`fix(pack): a failed write ends the transaction even when caught; a caught failed read does not`), merged to main after this run.
- Findings 2-4: open.

## Verdict
**pass** - checks 22/22 and every scenario criterion met: one Canvas declaring ACC-002 + CON-001 with the dependency in CON-001's Given, questions before code, RED then green, review PASS, spec-check clean, plan run (exit 8), no apply. The false Critical was closed on human evidence and is not counted as unresolved. Next run must re-check: the reviewer cites the caught-read rule instead of raising the abort claim; a rule/code mismatch in a scoped re-review is labelled Required; the CON- query test's decoy is seeded so a dropped filter fails.
