# Epic 6D Plan — XSD Semantic Constraints and Shape Fidelity

Date: 2026-03-14
Branch: `codex/epic-6c-merchant-wsdl-hardening`
Reference fixtures: inline synthetic WSDL/XSD regressions only

## Starting Point
- Epic 6C now covers:
  - doc/literal `element -> named complexType` wrapper resolution
  - `complexContent/simpleContent extension` flattening
  - Swift keyword escaping such as ``return``
  - generated semantic protocols for inherited complex types
  - repeated-element arrays, including finite `minOccurs/maxOccurs` validation
- Validation status at handoff:
  - `swift build -c debug` passes
  - `swift test --enable-code-coverage` passes
  - `swiftlint lint` passes with legacy warnings only

## Problem Statement
- The codegen now handles the most common real-world inheritance and wrapper failures, but the XSD subset is still structurally incomplete.
- Several schema semantics are either:
  - parsed but not enforced in generated `validate()`
  - represented only approximately in Swift output
  - not modeled at all yet

## Highest-Value Remaining Gaps
1. Numeric facet enforcement is incomplete.
   - `minInclusive`, `maxInclusive`, `totalDigits`, `fractionDigits` are parsed into facets.
   - Generated validation currently enforces string-length and regex checks, but not numeric constraints.
2. `choice` semantics are degraded to "all fields optional".
   - Mutual exclusivity and cardinality of choice branches are not enforced.
3. XML attribute vs element shape is still flattened in IR.
   - Parser captures attributes, but the generated models do not carry explicit field-kind metadata for downstream XML-shape-aware emission.
4. `simpleContent` is only partially supported.
   - Extension base metadata is captured, but value-vs-attribute semantics are not modeled as a first-class wire shape.

## Explicitly Deferred
- `xsi:type` runtime polymorphic dispatch
- abstract type dispatch
- substitution groups
- `group`, `attributeGroup`, `all`, `any`, `anyAttribute`
- `simpleType union` / `list`
- XSD restriction-based derivation

## Goals
1. Enforce the remaining high-value XSD facets already parsed by the schema layer.
2. Improve wire-shape fidelity where current emission is lossy but still tractable.
3. Keep generated Swift models ergonomic and flat unless true runtime polymorphism is implemented.

## Proposed Execution Order
1. Add focused regression tests for numeric facet validation.
   - `minInclusive`
   - `maxInclusive`
   - `totalDigits`
   - `fractionDigits`
2. Extend the IR only where needed for enforcement.
   - avoid over-modeling if current validation can be driven from existing facet data
3. Improve `choice` handling.
   - start with generated validation for "at least one / at most one" where schema structure is simple
   - avoid promising full polymorphic branch modeling yet
4. Decide whether XML field-kind metadata is needed immediately.
   - if yes, add explicit `element` vs `attribute` shape in IR
   - if no, document it as the next boundary before polymorphic work
5. Re-run compile/test/lint validation and update CHANGELOG.

## Acceptance Criteria
- Generated strict `validate()` enforces parsed numeric facets, not only regex/length checks.
- Repeated-field cardinality validation remains green.
- New synthetic regressions describe the supported subset without relying on external/private WSDLs.
- Required checks pass:
  - `swift build -c debug`
  - `swift test --enable-code-coverage`
  - `swiftlint lint`

## Recommendation
- Keep the next step focused on "semantic validation and shape fidelity", not polymorphism.
- Only start `xsi:type` / substitution-group work in a dedicated follow-up epic once the non-polymorphic XSD subset feels complete.
