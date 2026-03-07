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
- Added the initial runtime API split surface for Epic 3:
  - new Async modules: `SwiftSOAPClientAsync`, `SwiftSOAPServerAsync`;
  - new EventLoop/NIO modules: `SwiftSOAPClientNIO`, `SwiftSOAPServerNIO`;
  - typed operation contracts in `SwiftSOAPCore` (`SOAPOperationContract`, `SOAPOperationIdentifier`, `SOAPAction`, `SOAPOperationResponse`).
- Added contract-focused test targets for all new runtime surfaces:
  - `SwiftSOAPClientAsyncTests`,
  - `SwiftSOAPServerAsyncTests`,
  - `SwiftSOAPClientNIOTests`,
  - `SwiftSOAPServerNIOTests`.
- Added initial `SwiftSOAPWSDL` foundation for Epic 6:
  - new `SwiftSOAPWSDL` library target in modern manifests (`Package@swift-5.6.swift`, `Package@swift-6.0.swift`);
  - baseline in-memory WSDL model (`WSDLDefinition`) for messages, port types, bindings, and services;
  - bootstrap `WSDLDocumentParser` and dedicated `SwiftSOAPWSDLTests` target with initial parser coverage.
  - consistency validation in `WSDLDocumentParser` for cross-references between messages, port types, bindings, and services to support codegen-ready contracts.
  - enriched binding-operation metadata (`style`, `inputUse`, `outputUse`) plus validation of SOAP body `use` values for stricter codegen inputs.
- Added Epic 6B code generation foundation:
  - new `SwiftSOAPCodeGenCore` target with configuration model, diagnostics, canonical IR, and Swift emitter;
  - new `SwiftSOAPCodeGen` CLI executable supporting JSON config + CLI overrides;
  - added modern-manifest build tool plugin `SwiftSOAPCodeGenPlugin` (5.6/6.x manifests) invoking the same CLI contract.
- Added a dedicated latest-manifest for PackageDescription 6.1:
  - new `Package@swift-6.1.swift` for latest lane selection with additive manifest capabilities.
- Added Epic 6B Swift target-aware codegen controls:
  - `targetSwiftVersion` and `syntaxFeatures` in codegen configuration contract;
  - new CLI overrides `--target-swift` and repeatable `--syntax-feature <name>=<true|false>`;
  - syntax feature registry/policy with deterministic validation diagnostics.
- Extended `SwiftSOAPWSDL` semantic model and parser for codegen inputs:
  - added QName-aware model fields and first `types/XSD` model extraction (complex/simple types, sequence/choice, attributes);
  - added local `xsd:import`/`xsd:include` resolution support with explicit remote-location rejection in v1;
  - added SOAP binding matrix parsing metadata (SOAP 1.1/1.2, document/rpc, literal/encoded).
- Added XML Step 6 foundations in `SwiftSOAPXML`:
  - public XML AST types (`XMLQualifiedName`, `XMLTreeAttribute`, `XMLTreeNode`, `XMLTreeElement`, `XMLTreeDocument`) with structural metadata for xmlsig-oriented evolution;
  - parser/writer bridge (`XMLTreeParser`, `XMLTreeWriter`) for `Data/XMLDocument <-> XMLTreeDocument`;
  - namespace engine (`XMLNamespaceResolver`, `XMLNamespaceValidator`) with deterministic resolution and explicit diagnostics.
- Added XML Step `6.6M` macro mapping support on modern lanes:
  - new `SwiftSOAPXMLMacros` + `SwiftSOAPXMLMacroImplementation` targets in `Package@swift-6.0.swift` and `Package@swift-6.1.swift`;
  - new `@XMLNodeMapping(attributes:elements:)` macro generating `XMLFieldCodingOverrideProvider` metadata for runtime mapping parity with wrappers/overrides;
  - macro parity coverage in `XMLFieldMappingTests`.
- Added XML Step `6.6N` macro lane enablement for Swift 5.9:
  - new `Package@swift-5.9.swift` with macro targets/products enabled and path-based plugin integration;
  - lane-aware fixture manifest/tools-version support in codegen/plugin/runtime integration tests;
  - plugin manifest contract now validates 5.6/5.9/6.0/6.1 manifests.

### Changed
- Enabled Swift 6 language mode in the latest manifest lane:
  - `Package@swift-6.0.swift` now uses `swiftLanguageModes: [.v6]`.
- Hardened compatibility lane execution for deterministic test behavior on Linux:
  - `tooling-5.6+` now runs both build and tests in CI.
  - compatibility lanes use explicit single-worker test execution (`--parallel --num-workers 1`) where required to reduce flaky hangs.
- Hardened lane-specific manifest selection checks across CI/local matrix:
  - compatibility jobs now assert expected manifest resolution per lane (`5.6`, `5.9`, `5.10`, `latest`);
  - added explicit macro/plugin contract verification on the `macro-5.9` lane;
  - local matrix script now includes `macro-5.9` with lane-aware manifest assertions and build/test behavior.
- Unified GitHub Actions into a single lane-based workflow:
  - removed the separate `compatibility-skeleton` workflow;
  - `ci.yml` now owns all compatibility/quality lanes (`runtime-5.4`, `tooling-5.6+`, `macro-5.9`, `quality-5.10`, `latest`).
- Fixed CI reliability regressions observed after enabling latest-lane Swift 6 mode:
  - `compatibility-skeleton` now executes `tooling-5.6+` via `swift:5.6` Docker image (avoids `setup-swift` 404 on 5.6 artifacts).
  - `Build and Test` excludes the unstable `macos-14 + Swift 6.2` tuple caused by upstream `swift-nio` strict-concurrency compilation failures in dependency sources.
- Updated the local compatibility matrix script to align lane behavior with CI expectations:
  - `runtime-5.4` remains smoke (`swift package describe`),
  - `tooling-5.6+` runs build+test,
  - `quality-5.10` and `latest` run test coverage commands with serialized workers.
- Improved XML runtime safety for invalid tree mutations:
  - `XMLNode.addChild(_:)` now rejects self-child and ancestor-child insertions before calling libxml2 to prevent cycle-related undefined behavior.
- Added SOAP binding strategy contracts in `SwiftSOAPCore` for generated operation metadata validation across document/rpc and literal/encoded combinations.
- Refactored code generation emitter architecture to support automatic toolchain-based backend selection:
  - shared `SwiftSourceEmitter` contract + factory;
  - modern-lane `SwiftSyntaxBuilder` integration with fallback text emitter for compatibility lanes.
- Split plugin implementation by manifest capability:
  - `Package@swift-6.1.swift` uses URL-based plugin API surface via `Plugins/SwiftSOAPCodeGenPlugin61/Plugin.swift`;
  - `Package@swift-6.0.swift` keeps the existing `Path`-based plugin implementation for compatibility.
- Hardened XML ownership internals in preparation for deeper Swift 6 ownership work:
  - centralized `xmlChar*` lifetime management in `LibXML2.withOwnedXMLCharPointer(...)`;
  - strengthened `XMLDocument` storage invariants by making the owned `xmlDocPtr` non-optional.
- Added a Swift 6-only internal ownership layer for XML pointers:
  - new internal target `SwiftSOAPXMLOwnership6` (latest lane only);
  - first adoption of ownership syntax (`~Copyable`, `borrowing`, `consuming`) for `xmlChar*` wrappers, without changing public APIs.
  - expanded ownership wrappers to XPath context/object lifetimes, removing ad-hoc `defer` cleanup in Swift 6 XML XPath paths.
- Documented Epic 5 closure artifacts and scope boundaries:
  - added dedicated roadmap context and technical report for Swift 6 ownership prep;
  - classified non-latest local lane failures as environment/toolchain issues for separate infra follow-up (`ci-local-matrix` hardening).
- Backported source compatibility for Swift 5.6 parsing/type-checking in XML/core tests:
  - replaced shorthand optional-binding syntax with Swift 5.6-compatible forms where needed;
  - added explicit closure return types in libxml namespace helper paths.

- Upgraded the compatibility workflow from skeleton placeholders to lane-based executable checks:
  - `runtime-5.4` uses a legacy manifest smoke validation strategy in Docker (`swift:5.4`);
  - `tooling-5.6+` runs real build checks with Swift 5.6;
  - `quality-5.10` runs lint/build/test/coverage gates;
  - `latest` runs build/test on the latest lane.
- Updated versioned manifests (`Package@swift-5.6.swift`, `Package@swift-6.0.swift`) to expose and test Async/NIO split targets.
- Updated `agent.md` with explicit local multi-lane validation requirement for Swift-version-sensitive steps (`v0.17`).
- Introduced Epic 2 versioning scaffolding with a multi-manifest layout:
  - `Package.swift` now represents the legacy baseline (`swift-tools-version: 5.4`);
  - `Package@swift-5.6.swift` defines the current runtime/tooling package graph;
  - `Package@swift-5.9.swift` defines the modern pre-Swift-6 macro lane;
  - `Package@swift-6.0.swift` defines the latest-lane package graph.
- Updated CI/workflow scaffolding to align with versioned manifests:
  - cache key now tracks `Package.swift` and `Package@swift-*.swift`;
  - compatibility skeleton lanes now list and reference the versioned manifest set.
- Updated `agent.md` compatibility policy from single-version minimum to explicit lanes:
  - `runtime-5.4`, `tooling-5.6+`, `macro-5.9`, `quality-5.10`, `latest`;
  - explicit separation rule for `EventLoop` vs `async/await` API surfaces;
  - multi-manifest strategy documented under versioning rules.
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
- Updated `agent.md` compatibility guidance with explicit multi-version syntax rules:
  - require `#if swift(>=...)` gating when language syntax/features differ across supported lanes;
  - require equivalent fallback implementation for older lanes to preserve public behavior.
  - require proactive adoption of version-specific syntax where possible, with mandatory cross-version parity when public APIs are impacted.
- Hardened XML parser/writer safety and namespace policy surface:
  - introduced explicit XML parsing security policy controls in `XMLDocument` (network/entity/DTD handling);
  - added configurable parser/writer limits with default-unlimited semantics where safe and mandatory caps on concrete safety vectors;
  - added deterministic hardening diagnostics and tests for limit violations;
  - added explicit writer namespace validation mode (`strict` default, `synthesizeMissingDeclarations` opt-in).
- Updated `agent.md` execution workflow:
  - mandatory post-step advancement gate (no auto-advance without explicit user OK);
  - mandatory automatic commit proposal at significant technical checkpoints.

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
