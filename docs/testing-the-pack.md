---
_description: "How the skills are tested: pressure scenarios with hidden criteria, deterministic checks, a separate grader and mutation"
---

# How the pack is tested

This page summarises how the skills themselves are tested before a release. It is for readers who want to know how
much to trust an agent run, and for contributors who change a skill.

## Scenarios

The pack is tested like code. An eval is a pressure scenario: a fresh agent receives only a user story and, when the
scenario starts from an existing project, that project. It works through the story following the skills. Every
place it deviates, gets stuck or uses a wrong flag is a finding against a skill. The skill is fixed and the scenario
runs again until it passes cleanly. Each new scenario runs three times.

The acting agent is Claude Code or GitHub Copilot CLI.

## What makes a run pass

A run passes only when both independent checks pass:

- **Deterministic checks:** a script rebuilds the project, runs the tests itself, reads the registration from the
  compiled assembly, checks the package, the source and the Canvas, and, for scenarios with an org, runs a
  read-only `vela plan`.
- **A separate grader:** another agent reads the full scenario, including the criteria hidden from the actor, and
  judges what a script cannot, with cited evidence. It also plants violations in a copy of the code and checks that a
  fresh `vela-reviewer` catches each one at the expected severity.

The actor never sees the expected outcome, the planted violations or earlier run records, and never grades itself.

## Mutation

After a run, a tool plants one bug at a time in the authored code (a negated condition, a flipped comparison, a
dropped `throw`, assignment or query filter), rebuilds and reruns the tests. Each mutant the tests do not catch is
either a missing test or an equivalent change. Mutation is measured and does not yet fail a run.

## Structural checks

Every pull request runs a lint of the skills and agents, a check of these pages, the hook tests, the `spec-check`
tests, a secret scan, and a check that the generated Copilot files are in step with their sources.

## Results

Every run, failures included, is recorded with the CLI, framework and model versions it used. The scenarios, the
coverage of each skill and the pass rate of the latest campaign are in
[`evals/README.md`](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/evals/README.md).
