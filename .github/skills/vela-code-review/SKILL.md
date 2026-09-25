---
name: vela-code-review
description: Use once a plugin change's tests are green and analyzers are clean, before the apply gate, to review the diff for correctness, spec-fidelity, and Dataverse pitfalls.
---

# Review the change before the apply gate

Green tests and clean analyzers prove what you *thought* to check. A review catches the
registration-level mistakes that compile, pass a thin suite, and then fail on a live org
(dropped filtering attribute, unregistered image, Associate/Disassociate matched by entity,
dotted custom-API param). This gate sits between VERIFY and the apply gate.

## When to use

- After `vela-test-harness` is green and the build is analyzer-clean, before emitting the Build
  Report / reaching the apply gate.

## Process

Announce: `Using vela-code-review to review the change`.

1. Pin the base and confirm a non-empty diff: `git diff <base>...HEAD` (base = the branch point).
2. Review on **two axes** using `references/review-checklist.md`:
   - **Spec axis** — the diff against the **Vela Canvas** (acceptance cases + the Approach/Structure
     decisions: Sync/Async appropriate, reuse-vs-new respected). If the code diverged from the
     Canvas without the Canvas being updated first, that itself is a finding (fix-spec-first).
   - **Standards axis** — analyzer intent + the Dataverse smell baseline + **registration legality**
     (`registration-rules.md`) + **SOLID/DRY**.
3. Emit findings, most severe first: `severity — file:line — what — why — fix`. Severities:
   **Critical**, **Required**, **Nit**.
4. **Gate:** any unresolved **Critical/Required** blocks the apply gate — fix and re-verify
   (back to `vela-plugin-authoring` / `vela-test-harness`), then review again. Nits are optional.
5. Record the findings list in the Build Report.

## Self-review vs isolated reviewer (phased)

- **Now — self-review (default):** the builder runs this checklist against its own diff. Cheap,
  single-agent, always available.
- **Upgrade — isolated reviewer (`vela-reviewer` agent):** dispatch the **`vela-reviewer`** agent
  (read-only) given only the diff + the Vela Canvas + `references/review-checklist.md` (**not** the
  build's session history), so its judgement is not anchored by the author's context. Optionally
  run the two axes as two separate reviewers so one cannot mask the other. This is a **scoped
  review agent**, not `vela-builder` re-invoking itself — it does not violate "an agent applies
  skills, it does not orchestrate other personas."

## Rationalizations (excuse → rebuttal)

- "Tests are green, no need to review." → Tests prove the cases you imagined; review catches the
  registration bug you didn't think to test (the live-org failure class).
- "It's a tiny change, skip review." → Small diffs hide the subtle Dataverse smells; review is
  fast on a small diff.
- "I'll note the nit as done." → Only Critical/Required block; record nits honestly, don't inflate.

## Red flags

- Reaching the apply gate with no review findings list in the Build Report.
- A self-review that finds nothing on a diff that touches registration or images (look harder).
- Marking a Critical/Required finding resolved without re-running tests.

## Verification

- A findings list exists (most severe first) with a **PASS/BLOCK** verdict; no unresolved
  Critical/Required; the list is in the Build Report.
