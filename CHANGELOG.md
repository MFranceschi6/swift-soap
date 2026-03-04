# Changelog

All notable changes to this project will be documented in this file.

The format is inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Introduced the initial `SwiftSOAPCore` module with typed, `Codable` and `Sendable` SOAP domain models:
  - `SOAPEnvelope`, `SOAPBody`, `SOAPHeader`, `SOAPFault`.
  - payload protocols (`SOAPBodyPayload`, `SOAPHeaderPayload`, `SOAPFaultDetailPayload`) and empty marker payloads.
  - specialized value types for SOAP constants with fallback support (`SOAPEnvelopeNamespace`, `SOAPFaultCode`).
  - client/server transport contracts (`SOAPClientTransport`, `SOAPServerTransport`) and shared `SOAPCoreError`.
- Added `SwiftSOAPCore` test suite covering:
  - typed model initialization and validation behavior.
  - enum/raw fallback mapping and namespace/fault invariants.
  - codable round-trips for structured SOAP models.
  - transport protocol contract behavior with deterministic stubs.

### Changed
- Added Epic-based governance baseline for roadmap execution:
  - each roadmap step is handled as an epic on a dedicated `codex/epic-<n>-<slug>` branch and merged through a PR to `main`;
  - intermediate commits may relax only lint/test green status, while `swift build` and step reports remain mandatory.
- Added a compatibility CI skeleton workflow with placeholder lanes:
  - `runtime-5.4`,
  - `tooling-5.6+`,
  - `quality-5.10`,
  - `latest`.
- Updated `agent.md` pre-commit policy:
  - the mandatory pre-commit compliance gate can be simplified/skipped when changes are limited to configuration files only (e.g. `agent.md`, CI workflows, lint config, project metadata).
  - this exception applies only to pre-conditions; commit execution rules remain mandatory (selective staging, commit message convention, and `CHANGELOG.md` update).
- Updated `agent.md` style policy:
  - type declarations (`struct`/`class`/`enum`/`protocol`) must stay inline on a single line;
  - line breaks are allowed only after a `where` clause when needed for readability.
- Updated `agent.md` commit workflow policy:
  - commit message must describe the overall technical task scope, not the last micro-request;
  - when step reports are required, step closure must stop before commit and wait for explicit user go-ahead;
  - optional general context file is allowed to preserve task continuity.
- Updated `Package.swift` to expose the new `SwiftSOAPCore` library product and its dedicated test target.
- Reorganized implementation-bearing extensions into dedicated files (for example `+Logic`, `+Codable`) to align with repository conventions.
- Updated `SOAPEnvelope` declaration to enforce inline type declaration style, with a scoped SwiftLint `line_length` exception on the declaration line.

## [2026-03-04]

### Added
- Introduced the initial `SwiftSOAPXML` layer with:
  - `CLibXML2` system target integration.
  - XML document/node/namespace abstractions.
  - XPath support, serialization helpers, and parsing error surface.
  - Unit test coverage for XML behavior and edge cases.
- Commit: `f22404b` (`✨ feat: add SwiftSOAP XML layer implementation and tests`)

### CI
- Added GitHub Actions workflows for:
  - build and test execution.
  - SwiftLint validation.
- Commit: `2e20ed1` (`🧪 ci: add GitHub Actions lint and test workflows`)

### Chore
- Added baseline project configuration and agent guidance:
  - initial repository ignore/config files.
  - repository development rules in `agent.md`.
- Commit: `c176d10` (`⚙️ chore: add agent rules and base project configuration`)
