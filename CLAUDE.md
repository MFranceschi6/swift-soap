# CLAUDE.md — SwiftSOAP

Open-source Swift SOAP library. SPM-only. Linux-compatible runtime.

## Compatibility Lanes

`runtime-5.4` | `tooling-5.6-plus` | `macro-5.9` | `quality-5.10` | `latest`

Manifests: `Package.swift`, `Package@swift-5.6.swift`, `Package@swift-5.9.swift`,
`Package@swift-6.0.swift`, `Package@swift-6.1.swift`

## Required Validation (before any task closure)

```sh
swift build -c debug
swift test --enable-code-coverage
swiftlint lint
```

## Design Rules

- No raw strings for SOAP actions, operation IDs, or namespace URIs — use typed `String`-backed enums or `static let` constants.
- Typed errors (`enum` + `Error`). Stable error contracts. Include a generic fallback case on public error enums.
- Dual `#if swift(>=6.0)` typed-throws branches for all throw-capable public methods.
- `internal` by default; `public` only when intentional.
- Bug fixes must include regression tests. Features must cover core behavior and edge cases.
- Tests must be deterministic and isolated (no real network/time/filesystem dependencies).

## Safety

- Never revert unrelated local changes.
- No new dependencies without documented rationale (problem, alternatives, license/security, rollback).
- Always update `CHANGELOG.md` for completed technical tasks.
- Gitmoji commit prefix. Selective staging. Run `scripts/install-git-hooks.sh` once per worktree.
- Branch naming: `claude/epic-<n>-<slug>`.

## Skills

Invoke with `/skill-name`. Details in `.claude/skills/<name>/SKILL.md`.

| Skill | When to invoke |
| --- | --- |
| `baseline-validation` | Before any task closure — run build/test/lint gates |
| `step-report-and-changelog` | When work is functionally complete — step report + CHANGELOG |
| `commit-checkpoint` | At a meaningful checkpoint — safe commit preparation |

## Deep-Dive Policy (read on demand only)

- `.claude/agent/01-project-profile.md` — scope, platform, dependency policy
- `.claude/agent/02-engineering-standards.md` — API design, file structure, concurrency
- `.claude/agent/03-validation-and-quality-gates.md` — coverage targets, test isolation
- `.claude/agent/04-workflow-reporting-and-commits.md` — workflow, branching, reporting
- `.claude/agent/05-skills-and-context-organization.md` — skill authoring rules
