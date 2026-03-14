# Epic 6D Checklist — XSD Semantic Constraints and Shape Fidelity

Date: 2026-03-14
Related plan: `epic-6d-xsd-semantics-follow-up-plan.md`

## Regression Coverage
- [ ] Add inline regression for `minInclusive` validation.
- [ ] Add inline regression for `maxInclusive` validation.
- [ ] Add inline regression for `totalDigits` validation.
- [ ] Add inline regression for `fractionDigits` validation.
- [ ] Add focused regression describing current `choice` limitations before changing behavior.

## Codegen Core
- [ ] Enforce numeric facets already parsed into `FacetConstraintIR`.
- [ ] Keep generated diagnostic codes stable and additive.
- [ ] Preserve current array cardinality validation behavior.
- [ ] Avoid introducing runtime-polymorphic code paths in this step.

## Shape Fidelity
- [ ] Decide whether `GeneratedTypeFieldIR` needs explicit field-kind metadata (`element` vs `attribute`).
- [ ] If needed, thread field-kind metadata from parser -> IR -> emitter/tests.
- [ ] Reassess `simpleContent` wire-shape representation after numeric facets are done.

## Validation
- [ ] `swift build -c debug`
- [ ] `swift test --enable-code-coverage`
- [ ] `swiftlint lint`
- [ ] Update `CHANGELOG.md`

## Discipline
- [ ] Use only synthetic inline WSDL/XSD fixtures in tests.
- [ ] Keep protocol generation and flat concrete DTO emission unchanged unless a failing regression demands otherwise.
- [ ] Defer `xsi:type`, abstract dispatch, and substitution groups to a dedicated later epic.
