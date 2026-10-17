---
name: vela-code-review
description: Use once a plugin change's tests are green and analyzers are clean, before the apply gate, to review the diff for correctness, spec-fidelity, and Dataverse pitfalls.
compatibility: "vela CLI >= 0.26.0 (Vela.Plugins >= 0.35.0); dotnet SDK."
---

# Review the change before the apply gate

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Green tests and clean analyzers prove what you *thought* to check. A review catches the
registration-level mistakes that compile, pass a thin suite, and then fail on a live org
(wrong filtering attribute, image read through an untyped alias, Associate/Disassociate without
`ForRelationship`, a Custom API unique name without the publisher prefix, a self-triggering write
"guarded" by `SkipWhenDepthAbove`). What the analyzers already enforce (VELA020, VELA023, VELA017 ...)
is marked as such in the checklist - the review covers what the build cannot see. This gate sits between VERIFY and the apply gate.

## When to use

- After `vela-test-harness` is green and the build is analyzer-clean, before emitting the Build
  Report / reaching the apply gate. Hand the reviewer the build's summary/diagnostic lines too, so it
  can rely on the analyzer-enforced items.

## Process

Announce: `Using vela-code-review to review the change`.

1. Pin the base and confirm a non-empty diff: commit your work first, then `git diff <base>...HEAD`
   (base = the branch point; uncommitted changes are not in it). No repository (e.g. a fresh scratch
   run)? `git init` + commit right after scaffolding and diff against that commit; if git is not
   allowed, diff against a copy of the tree taken right after scaffolding (`diff -ruN`). Say which.
   Keep the diff reviewable: hand generated models (`vela models` output) over as
   `git diff --stat` - they are not reviewed line by line - and the
   rest in full; the scaffold writes CRLF files, so keep CRLF when editing or use
   `git diff --ignore-cr-at-eol`.
2. Review on **two axes** using `references/review-checklist.md` (harness semantics - e.g. what
   `PluginContext...Execute` auto-derives, why "does not fire" needs `PluginPipeline` - are in
   `references/harness-api.md`; CLI facts - e.g. `plan` needs `--solution` - in `references/cli-surface.md`; handler shapes in
   `references/plugin-authoring-api.md`):
   - **Spec axis** - the diff against the **Vela Canvas** (acceptance cases + the Approach/Structure
     decisions: Sync/Async appropriate, reuse-vs-new respected). If the code diverged from the
     Canvas without the Canvas being updated first, that itself is a finding (fix-spec-first).
   - **Standards axis** - analyzer intent + the Dataverse smell baseline + **registration legality**
     (`registration-rules.md`) + **SOLID/DRY**.
3. Emit findings, most severe first: `severity - file:line - what - why - fix`. Severities:
   **Critical**, **Required**, **Nit**.
4. **Gate:** any unresolved **Critical/Required** blocks the apply gate - fix and re-verify
   (back to `vela-plugin-authoring` / `vela-test-harness`), then review again. Nits are optional.
5. Record the findings list in the Build Report (`references/build-report-template.md`).

## Who reviews: the isolated reviewer by default

- **Default - isolated reviewer (`vela-reviewer` agent):** dispatch the **`vela-reviewer`** agent
  (read-only, no shell) with only: the diff **text pasted into its prompt**, the Vela Canvas, the test
  runner's verbatim RED/GREEN lines and the Run trace - **not** the build's session history, so its
  judgement is not anchored by the author's context. After a fix, dispatch a **fresh** reviewer on the
  new diff. Hand over the real material, never a placeholder ("<diff here>"): write the diff, Canvas and
  RED/GREEN output to files first and paste their contents. A reviewer that blocks for missing evidence
  is answered by fixing the evidence and dispatching a **fresh** reviewer, not by re-asking the same one.
  Save the reviewer's verbatim output next to the Build Report. Optionally run the two axes as two separate reviewers so one cannot mask the other. This is
  a **scoped review agent**, not `vela-builder` re-invoking itself - it does not violate "an agent
  applies skills, it does not orchestrate other personas."
  Why the default: in the eval runs the isolated reviewer caught what self-review passed (a Function
  called by flows; an unplanned write) and blocked every planted violation.
- **Fallback - self-review:** only when the host cannot dispatch a subagent. Run this checklist
  against your own diff and **say so in the Build Report** ("self-review: no subagent available").

## Rationalizations (excuse → rebuttal)

- "Tests are green, no need to review." → Tests prove the cases you imagined; review catches the
  registration bug you didn't think to test (the live-org failure class).
- "It's a tiny change, skip review." → Small diffs hide the subtle Dataverse smells; review is
  fast on a small diff.
- "I'll note the nit as done." → Only Critical/Required block; record nits honestly, don't inflate.

## Red flags

- Reaching the apply gate with no review findings list in the Build Report.
- A reviewer prompt that contains a placeholder (`<diff>`, `<paste here>`, "see above") instead of the
  material itself - check the prompt before dispatching; a verdict on a placeholder is void.
- A self-review where a subagent could have been dispatched, or a self-review not labelled as such in
  the Build Report.
- A self-review that finds nothing on a diff that touches registration or images (look harder).
- Marking a Critical/Required finding resolved without re-running tests.

## Verification

- A findings list exists (most severe first) with a **PASS/BLOCK** verdict; no unresolved
  Critical/Required; the list is in the Build Report.
