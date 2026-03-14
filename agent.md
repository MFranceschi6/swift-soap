# Agent Policy Entry Point (Claude Code)

This repository no longer keeps agent policy in a single monolithic file.
`agent.md` is the canonical entry point and routing file for all operational rules.

## Mandatory Load Order

1. `Docs/agent/01-project-profile.md`
2. `Docs/agent/02-engineering-standards.md`
3. `Docs/agent/03-validation-and-quality-gates.md`
4. `Docs/agent/04-workflow-reporting-and-commits.md`
5. `Docs/agent/05-skills-and-context-organization.md`
6. `Docs/agent/99-agent-policy-changelog.md`

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

## Context Layout (Claude Code)

- Ephemeral/local agent context: `.claude/`
- Long-lived technical docs/reports: repository `Docs/` and `.claude/report/` when appropriate.
- Repository skills: `.claude/skills/<skill-name>/SKILL.md`

## Skill Registry (Current)

- `baseline-validation`
- `step-report-and-changelog`
- `commit-checkpoint`

Details and usage rules are defined in:
- `Docs/agent/05-skills-and-context-organization.md`
