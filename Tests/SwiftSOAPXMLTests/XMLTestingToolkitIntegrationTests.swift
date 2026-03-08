import Foundation
import SwiftSOAPXML
import SwiftSOAPXMLTestSupport
import XCTest

final class XMLTestingToolkitIntegrationTests: XCTestCase {
    private struct Payload: Codable, Equatable {
        let value: String
    }

    func test_encoderDecoderSpies_recordCalls_forRoundtrip() throws {
        let payload = Payload(value: "ok")
        let encoderSpy = XMLTestEncoderSpy(
            encoder: XMLEncoder(configuration: .init(rootElementName: "Payload"))
        )

        let encodedData = try encoderSpy.encode(payload)
        XCTAssertEqual(encoderSpy.calls.count, 1)
        XCTAssertEqual(encoderSpy.calls.first?.method, .encodeData)
        XCTAssertEqual(encoderSpy.calls.first?.valueTypeName, String(reflecting: Payload.self))

        let decoderSpy = XMLTestDecoderSpy(
            decoder: XMLDecoder(configuration: .init(rootElementName: "Payload"))
        )
        let decoded = try decoderSpy.decode(Payload.self, from: encodedData)
        XCTAssertEqual(decoded, payload)
        XCTAssertEqual(decoderSpy.calls.count, 1)
        XCTAssertEqual(decoderSpy.calls.first?.method, .decodeData)
        XCTAssertEqual(decoderSpy.calls.first?.valueTypeName, String(reflecting: Payload.self))
        XCTAssertTrue((decoderSpy.calls.first?.payloadSize ?? 0) > 0)
    }

    func test_encoderSpy_forcedError_isDeterministic() {
        let encoderSpy = XMLTestEncoderSpy()
        encoderSpy.forcedError = XMLTestCodecError.forcedFailure(message: "forced-encode-failure")

        XCTAssertThrowsError(try encoderSpy.encode(Payload(value: "boom"))) { error in
            XCTAssertEqual(
                error as? XMLTestCodecError,
                .forcedFailure(message: "forced-encode-failure")
            )
        }
    }

    func test_canonicalizerHarness_assertsTransformOrderAndFailureEnvelope() throws {
        try XMLCanonicalizerContractHarness.assertTransformOrder(tokens: ["A", "B", "C"])
        try XMLCanonicalizerContractHarness.assertTransformFailureEnvelope()
    }
}
