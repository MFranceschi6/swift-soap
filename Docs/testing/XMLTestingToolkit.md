# XML Testing Toolkit (XML-6.9T)

This toolkit provides reusable test doubles and canonicalization contract probes for XML runtime and codegen tests.

Import module: `SwiftSOAPXMLTestSupport`

## Components
- `XMLTestEncoderSpy`
  - wraps `XMLEncoder`, records encode calls (`encode` / `encodeTree`), supports forced failure and optional stubbed outputs.
- `XMLTestDecoderSpy`
  - wraps `XMLDecoder`, records decode calls (`decode` / `decodeTree`), supports forced failure and optional stubbed outputs.
- `XMLTestCallRecorder`
  - thread-safe call recorder used by transform/canonicalizer contract tests.
- `XMLTestRecordingTransform` / `XMLTestFailingTransform`
  - deterministic transform doubles for pipeline ordering and failure-path validation.
- `XMLCanonicalizerContractProbe`
  - reusable probe helpers for canonicalizer/transform contract behavior:
    - deterministic transform order,
    - stable transform failure envelope.

## Intended usage
- Use spies in runtime/codegen tests when you need deterministic call-flow assertions without introducing ad-hoc stubs.
- Use canonicalizer probe helpers when validating custom canonicalizer implementations and adapters built on top of the public XML canonicalization contract.

## Integration example
See:
- `Tests/SwiftSOAPXMLTests/XMLTestingToolkitIntegrationTests.swift` for XML runtime usage.
- `Tests/SwiftSOAPCodeGenCoreTests/XMLTestingToolkitContractUsageTests.swift` for codegen target usage.
