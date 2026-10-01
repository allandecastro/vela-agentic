---
scenario: account-second-behaviour
date: 2026-10-02
verdict: pass
campaign: 2026-10-02
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.4
framework: 0.29.11
runner: "campaign actor + separate grader"
---

## Loop outcome
- Check report (`checks.json`): **16/16 passed**, no failed check. Highlights: build succeeds, no VELA diagnostics,
  tests re-run green (total=10 failed=0), Update account PreOperation/Synchronous filter=['description'] registered,
  exactly 2 authored steps, no write-back, "Created via Vela plugin" in exactly one source file.
- Actor loop (from `work/ZavaSales` git log `main..HEAD` and `docs/vela-builds/account-description-reapply-on-clear.md`):
  `vela version` → 0.21.4 · Canvas (68d97f2) · `vela add step AccountDefaultDescription --entity Account --message Update
  --stage PreOperation --mode Sync --filtering-attributes Description` (3ce14be, exit 0) · RED tests (d3fc865,
  Total 10 / Failed 4) · implementation (89f711f, GREEN 10/10, 0 warn / 0 err) · review #1 BLOCK (1 Required) → fix
  c46e220 → review #2 PASS · Release package built, sha256 recorded · `vela plan` skipped - no org (exact command
  recorded) · stopped before apply.
- Grader re-verification: cloned the work and checked out d3fc865. Built 0 warn / 0 err, then ran the mono xunit console with `-parallel none`:
  `Total: 10, Errors: 0, Failed: 4`. The four failures are the Update cleared-to-null, cleared-to-empty, whitespace, and the pipeline
  saved-value test. RED is confirmed independently.

## Criteria

| # | Criterion | Met? | Evidence |
|---|---|---|---|
| D1 | Reuse vs new: `vela add step` on the existing plugin, not a hand-created class | met | commit 3ce14be ("scaffold Update step ... (vela add step)") adds the `vela add step` TODO stub; Canvas l.20 `reuse: add-step:AccountDefaultDescription`, A - Approach l.62-64; Run trace row 3 |
| D2 | DRY: rule defined once, shared by Create + Update (helper + constant) | met | `AccountDefaultDescription.cs:15` single `const DefaultDescription`; `:53-62` `ApplyDefaultIfEmpty` called from `:39` (Update) and `:49` (Create); check "src contains /Created via Vela plugin/" → one file |
| D3 | Sync PreOperation, set on `ctx.Request.Target` | met | `AccountDefaultDescription.cs:26-31,36`; check "step registered: Update account PreOperation/Synchronous"; Canvas A l.59-61 states the reason |
| D4 | Filtering `FilterOn(e => e.Description)` | met | `AccountDefaultDescription.cs:29`; check filter=['description'] |
| S1 | Canvas Approach/Structure record reuse, sharing mechanism, and Sync with a reason | met | Canvas l.58-69 (Approach: "Sync because the record must never be committed with an empty Description"; reuse via `vela add step`; Structure: "a private helper + a constant, not a service (one-liner, single plugin)") |
| S2 | No duplicated defaulting logic; one definition used by both paths; decision + correct reason recorded | met | see D2; Canvas S - Structure l.67-69, N - Norms l.83 |
| S3 | Test-first: RED acceptance tests (cleared → re-defaulted; real value → untouched) before impl, green after | met | `AccountDefaultDescriptionTests.cs:43-46,71-83`; RED at d3fc865 reproduced by the grader (4 failed); GREEN at HEAD per check "tests re-run green" (10/0) |
| S4 | `vela-code-review` PASS; SOLID/DRY axis confirms no duplication; spec axis confirms reuse honoured | met | `work/review/reviewer-2.md`: "PASS - no Critical/Required"; standards axis "DRY private helper + constant"; spec axis "reuse via vela add step; no service" |

## Planted-violation check
Each plant was applied to a copy (`planted-<x>/ZavaSales`) and built. A fresh general-purpose subagent was then dispatched, acting as
`vela-reviewer` (read-only), and given only the original→planted diff and the Canvas.

| Plant | Build | Verdict | Severity of the planted finding | Expected | Result |
|---|---|---|---|---|---|
| (a) defaulting logic copy-pasted into a second class (`AccountDescriptionUpdateDefaults` with its own const + IsNullOrWhiteSpace logic, used by HandleUpdate) | 0 err / 0 warn | BLOCK | **Required** (DRY: rule + constant duplicated between steps) plus Required Canvas drift | Required | pass |
| (b) hand-created plugin class `AccountDescriptionReapply` holding the Update step (helper widened to internal) | 0 err / 0 warn | BLOCK | **Required** (hand-created class reverses the Canvas `add step` decision; suggests `vela add plugin` if really wanted) plus Required cross-plugin coupling | Required | pass |
| (c) step registered Async (`.PreOperation().Async()` does not compile: CS1061 on `ISyncMode<IUpdatePreOperationConfig<Account>>`, so the plant was `.PostOperation().Async()` with `IUpdatePostContext<Account>`) | 0 err / 0 warn | BLOCK | **Critical** (Target edit after commit is never saved, so the default is never applied; Approach mismatch) | Critical | pass |

All three plants were blocked at the expected severity or higher. Each reviewer also raised a Required
"stale evidence" finding for its plant, which is correct.

## Findings against the skills
None. Every pack instruction this run exercised led the actor to the correct path: reuse by
`vela add step`, a private helper + constant instead of a service, Sync PreOperation, RED before GREEN, a fresh
reviewer, and stopping at the apply gate.

Observations (not skill defects; reported for the Vela repo, no workaround proposed):
- Framework 0.29.11 makes `PreOperation().Async()` unrepresentable, which is good. But `PostOperation().Async()` with a
  handler that edits `ctx.Request.Target` builds with 0 warnings: no VELA analyzer flags a Target edit that is never
  saved. Only the review gate caught plant (c).
- The baseline's Create step has `.FilterOn(e => e.Name)`, and Dataverse ignores filtering attributes on Create. This is
  inherited from `account-default-description` and was not flagged by either reviewer. It is out of scope for this
  scenario.

## Fixes
- None needed.

## Verdict
**pass**: checks 16/16, and the grader found every criterion met and every planted violation blocked at the expected
severity. The next run must re-check that the RED commit precedes the implementation commit and that the Update step
stays inside the existing plugin.
