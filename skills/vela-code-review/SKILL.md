---
name: vela-code-review
description: Use once a plugin change's tests are green and analyzers are clean, before the apply gate, to review the diff for correctness, spec-fidelity, and Dataverse pitfalls.
compatibility: "vela CLI + dotnet SDK."
---

# Review the change before the apply gate

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Green tests and clean analyzers prove what you *thought* to check. Review catches the
registration-level mistakes that compile, pass a thin suite and fail on a live org (the checklist lists
them; analyzer-enforced items are marked - review what the build cannot see). Sits between VERIFY and
the apply gate.

## When to use

- Tests green and build analyzer-clean, before the Build Report. Hand the reviewer the build's
  summary/diagnostic lines too.

## Process

Announce: `Using vela-code-review to review the change`.

1. Commit, then `git diff <base>...HEAD` (base = branch point) and confirm it is non-empty. No
   repository? `git init` + commit right after scaffolding; no git? `diff -ruN` against a post-scaffold
   copy. Say which. Generated models as `git diff --stat`, the rest in full (the scaffold writes
   CRLF: keep it when editing, or `git diff --ignore-cr-at-eol`).
2. **Real material in the reviewer's prompt** (plus the path of `docs/adr/`, which it reads itself): write diff, Canvas and RED/GREEN lines to files, paste
   their **contents**, check for placeholders (`<diff>`, `<paste here>`, "see above"). A verdict on a
   placeholder is void.
3. Review on **two axes** with `references/review-checklist.md` (also `references/harness-api.md`,
   `references/cli-surface.md`, `references/plugin-authoring-api.md`):
   - **Spec** - the diff against the **Vela Canvas** (acceptance cases, Approach/Structure decisions:
     Sync/Async, reuse-vs-new). Code that diverged without the Canvas updated first is itself a finding
     (fix-spec-first).
   - **Standards** - analyzer intent + Dataverse smell baseline + **registration legality**
     (`references/registration-rules.md`) + **SOLID/DRY**.
4. Emit findings, most severe first: `severity - file:line - what - why - fix`, severity **Critical**,
   **Required** or **Nit**.
5. **Gate:** any unresolved **Critical/Required** blocks the apply gate - fix, re-verify
   (`vela-plugin-authoring` / `vela-test-harness`), review again. Nits are optional. A finding on a rule's
   text in `docs/rules/` is not fixed in the build: it goes to the Gate as an open item for the human.
6. Record the findings in the Build Report (`references/build-report-template.md`).

## Spec check (deterministic, before dispatching the reviewer)

Run `dotnet run <pack>/tools/spec-check.cs -- --base <base> --canvas docs/features/<slug>/README.md` in the project
(the pack is the folder holding `skills/`; after the Release build - it reads the restored Vela.Plugins), with the **latest** base: `git fetch` then `origin/<main>` when there is a
remote, else the local main - read-only, never merge it into the branch. It fails when the registry changed outside the rules the Canvas declares,
an existing test was modified / deleted for a rule the story does not
change, or the story takes a rule id / ADR number already used on the base. Paste its output into the reviewer's material; a failure is a **BLOCK** before any review. A `NOTE` (an id
already duplicated on the base, by two merged stories) does not block: report it to the human for a separate
renumbering change, never renumber it in this story. "nothing to check" (no
registry) is recorded as **not checked**, never as a pass.

## Who reviews: the isolated reviewer by default

- **Default - `vela-reviewer` agent** (read-only, no shell), given only the pasted diff, the Canvas, the
  verbatim RED/GREEN lines and the Run trace - **not** the session history, so the author's context does
  not anchor it (in eval runs it caught what self-review passed). **One** reviewer covers both axes. Save its
  verbatim output as `.vela-runs/<slug>/review.md` (untracked; later rounds appended) and quote it in the PR.
- **Proportional re-review** (the review is the costliest step of a build): after fixing its findings, or
  after a small later change (trace text, comment, wording), dispatch a fresh reviewer with **only** that
  diff, the findings it must close and the new RED/GREEN lines - not the whole material again. A **full**
  review again only when the change touches the registration, the security context, data access, an
  outbound call, or most of the code. A block for missing evidence: fix the material, same scoped round.
- **Fallback - self-review**, only when no subagent can be dispatched; **say so in the Build Report**
  ("self-review: no subagent available").

## Rationalizations (excuse → rebuttal)

- "Tests are green, no need to review." → Tests prove the cases you imagined; review catches the
  registration bug you didn't test.
- "It's a tiny change, skip review." → Small diffs hide Dataverse smells; review is fast on them.
- "I'll note the nit as done." → Only Critical/Required block; record nits honestly.

## Red flags

- Reaching the apply gate with no findings list in the Build Report.
- A reviewer prompt with a placeholder instead of the material.
- Self-review where a subagent could have been dispatched, or not labelled as such.
- A self-review that finds nothing on a diff touching registration or images (look harder).
- A Critical/Required marked resolved without re-running tests.

## Verification

- A findings list (most severe first) with a **PASS/BLOCK** verdict, no unresolved Critical/Required,
  recorded in the Build Report.
