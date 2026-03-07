import SwiftSOAPCore
import XCTest

final class SOAPBindingStrategyTests: XCTestCase {
    func test_validate_documentLiteral_succeeds() throws {
        let metadata = SOAPBindingMetadata(envelopeVersion: .soap11, style: .document, bodyUse: .literal)
        let strategy = SOAPBindingCodecFactory.makeCodecStrategy(for: metadata)
        XCTAssertNoThrow(try strategy.validate(metadata: metadata))
    }

    func test_validate_rpcLiteral_succeeds() throws {
        let metadata = SOAPBindingMetadata(envelopeVersion: .soap12, style: .rpc, bodyUse: .literal)
        let strategy = SOAPBindingCodecFactory.makeCodecStrategy(for: metadata)
        XCTAssertNoThrow(try strategy.validate(metadata: metadata))
    }

    func test_validate_rpcEncoded_succeeds() throws {
        let metadata = SOAPBindingMetadata(envelopeVersion: .soap12, style: .rpc, bodyUse: .encoded)
        let strategy = SOAPBindingCodecFactory.makeCodecStrategy(for: metadata)
        XCTAssertNoThrow(try strategy.validate(metadata: metadata))
    }

    func test_validate_documentEncoded_fails() {
        let metadata = SOAPBindingMetadata(envelopeVersion: .soap11, style: .document, bodyUse: .encoded)
        let strategy = SOAPBindingCodecFactory.makeCodecStrategy(for: metadata)

        XCTAssertThrowsError(try strategy.validate(metadata: metadata)) { error in
            guard case SOAPCoreError.unsupportedBinding = error else {
                return XCTFail("Expected unsupportedBinding, got \(error)")
            }
        }
    }
}
