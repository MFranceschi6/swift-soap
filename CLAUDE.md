# CLAUDE.md

Claude Code operational guide for this repository.
Canonical policy entry point: `agent.md`.

## Policy Loading

Read in this order:
1. `agent.md`
2. `Docs/agent/01-project-profile.md`
3. `Docs/agent/02-engineering-standards.md`
4. `Docs/agent/03-validation-and-quality-gates.md`
5. `Docs/agent/04-workflow-reporting-and-commits.md`
6. `Docs/agent/05-skills-and-context-organization.md`

## Required Validation

- `swift build -c debug`
- `swift test --enable-code-coverage`
- `swiftlint lint`

## Skill Registry

Repository skills are tracked in `.claude/skills/`:
- `baseline-validation`
- `step-report-and-changelog`
- `commit-checkpoint`

## Safety

- Do not revert unrelated local changes.
- Do not introduce new dependencies unless justified.
- Always update `CHANGELOG.md` for completed technical tasks.
