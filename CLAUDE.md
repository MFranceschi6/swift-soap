# CLAUDE.md

This file is a Claude-oriented operational guide for this repository.
For full project policy and detailed workflow constraints, see `agent.md`.

## Project Profile
- Swift Package Manager only.
- Linux-compatible runtime behavior is required.
- Multi-lane compatibility model:
  - `runtime-5.4`
  - `tooling-5.6-plus`
  - `macro-5.9`
  - `quality-5.10`
  - `latest`
- Manifests:
  - `Package.swift` (legacy baseline)
  - `Package@swift-5.6.swift`
  - `Package@swift-5.9.swift`
  - `Package@swift-6.0.swift`
  - `Package@swift-6.1.swift`

## Execution Priorities
- Keep public APIs explicit, stable, and documented.
- Prefer extensions and small focused files.
- Match repository naming conventions (`Type.swift`, `Type+Logic.swift`, etc.).
- Avoid Apple-only APIs in runtime code paths.
- Include regression tests for bug fixes and meaningful coverage for feature changes.
- **No raw strings for domain values**: when a value is a named domain concept (operation
  identifier, SOAP action, binding name, namespace URI, etc.), represent it as a typed
  constant, `static let`, or enum case — never a bare string literal at call sites.
  In code-generated output this means generating named `static let` constants or enum
  namespaces from WSDL metadata rather than inline `rawValue:` string literals.

## Required Validation (before closure)
- Build:
  - `swift build -c debug`
- Tests:
  - `swift test --enable-code-coverage`
- Lint:
  - `swiftlint lint`

If a task is lane-sensitive, run lane-specific checks with:
- `./scripts/ci-local-matrix.sh`
- `./scripts/ci-local-matrix.sh --lane <lane>`

Local matrix reports default to:
- `.claude/report/local-matrix`

Override when needed:
- `LOCAL_MATRIX_REPORT_ROOT=.cursor/report/local-matrix ./scripts/ci-local-matrix.sh`

## Context and Reporting
- Keep transient agent context under `.claude/` by default.
- Keep long-lived technical artifacts (plans/reports) where the repository already expects them.
- Always update `CHANGELOG.md` for completed technical tasks.

## Safety Rules
- Do not introduce new dependencies unless necessary and justified.
- Do not perform destructive cleanup (`rm -rf`, hard resets) without explicit user approval.
- Never revert unrelated local changes.
