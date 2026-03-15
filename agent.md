# Agent Policy Entry Point (Claude Code)

`CLAUDE.md` is auto-loaded and contains all routine policy. This file is the reference index
for deep-dive modules — read individual modules only when the task requires it.

## Deep-Dive Modules

1. `.claude/agent/01-project-profile.md` — scope, platform, dependency policy
2. `.claude/agent/02-engineering-standards.md` — API design, file structure, concurrency
3. `.claude/agent/03-validation-and-quality-gates.md` — coverage targets, test isolation
4. `.claude/agent/04-workflow-reporting-and-commits.md` — workflow, branching, reporting
5. `.claude/agent/05-skills-and-context-organization.md` — skill authoring rules
6. `.claude/agent/99-agent-policy-changelog.md` — policy change history

## Non-Negotiable Gates

- SPM-only project, Linux-compatible runtime behavior required.
- Lane model is mandatory: `runtime-5.4`, `tooling-5.6-plus`, `macro-5.9`, `quality-5.10`, `latest`.
- Required validation before closure:
  - `swift build -c debug`
  - `swift test --enable-code-coverage`
  - `swiftlint lint`
- Always update `CHANGELOG.md` for completed technical work.
- Never revert unrelated local changes.
- Do not introduce new dependencies unless justified and documented.

## Skill Registry

Skills live in `.claude/skills/<skill-name>/SKILL.md`:

- `baseline-validation`
- `step-report-and-changelog`
- `commit-checkpoint`
