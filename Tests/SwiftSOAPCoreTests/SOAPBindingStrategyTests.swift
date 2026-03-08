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

    // SOAPDocumentLiteralCodecStrategy: validate with non-matching metadata (e.g. rpc/literal)
    func test_documentLiteralStrategy_validate_withRPCMetadata_throws() {
        let strategy = SOAPDocumentLiteralCodecStrategy()
        let rpcMeta = SOAPBindingMetadata(envelopeVersion: .soap11, style: .rpc, bodyUse: .literal)
        XCTAssertThrowsError(try strategy.validate(metadata: rpcMeta)) { error in
            guard case SOAPCoreError.unsupportedBinding = error else {
                return XCTFail("Expected unsupportedBinding, got \(error)")
            }
        }
    }

    // SOAPRPCLiteralCodecStrategy: validate with non-matching metadata (e.g. document/literal)
    func test_rpcLiteralStrategy_validate_withDocumentMetadata_throws() {
        let strategy = SOAPRPCLiteralCodecStrategy()
        let docMeta = SOAPBindingMetadata(envelopeVersion: .soap11, style: .document, bodyUse: .literal)
        XCTAssertThrowsError(try strategy.validate(metadata: docMeta)) { error in
            guard case SOAPCoreError.unsupportedBinding = error else {
                return XCTFail("Expected unsupportedBinding, got \(error)")
            }
        }
    }

    // SOAPBindingOperationContract default extension: validateBinding() succeeds for default doc/lit
    func test_bindingOperationContract_validateBinding_defaultMetadata_succeeds() throws {
        // MinimalBindingOperation uses the default SOAPBindingOperationContract.bindingMetadata (doc/lit soap11)
        XCTAssertNoThrow(try MinimalBindingOperation.validateBinding())
    }

    func test_bindingOperationContract_defaultBindingMetadata_isDocumentLiteralSOAP11() {
        let metadata = MinimalBindingOperation.bindingMetadata
        XCTAssertEqual(metadata.envelopeVersion, .soap11)
        XCTAssertEqual(metadata.style, .document)
        XCTAssertEqual(metadata.bodyUse, .literal)
    }
}

// Minimal operation using default SOAPBindingOperationContract bindingMetadata
private struct EmptyPayload: SOAPBodyPayload {}
private struct EmptyFault: SOAPFaultDetailPayload {}

private enum MinimalBindingOperation: SOAPBindingOperationContract {
    static let operationIdentifier = SOAPOperationIdentifier(rawValue: "Minimal")
    static var soapAction: SOAPAction? { nil }
    // Does NOT override bindingMetadata — uses the extension default
    typealias RequestPayload = EmptyPayload
    typealias ResponsePayload = EmptyPayload
    typealias FaultDetailPayload = EmptyFault
}
