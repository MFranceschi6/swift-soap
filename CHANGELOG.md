# Changelog

All notable changes to this project will be documented in this file.

The format is inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed
- Updated `agent.md` pre-commit policy:
  - the mandatory pre-commit compliance gate can be simplified/skipped when changes are limited to configuration files only (e.g. `agent.md`, CI workflows, lint config, project metadata).
  - this exception applies only to pre-conditions; commit execution rules remain mandatory (selective staging, commit message convention, and `CHANGELOG.md` update).

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
