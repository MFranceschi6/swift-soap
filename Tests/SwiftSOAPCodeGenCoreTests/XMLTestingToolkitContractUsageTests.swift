import Foundation
import SwiftSOAPXML
import SwiftSOAPXMLTestSupport
import XCTest

final class XMLTestingToolkitContractUsageTests: XCTestCase {
    private struct Payload: Codable, Equatable {
        let value: String
    }

    func test_encoderDecoderSpies_areUsableInCodeGenTests() throws {
        let payload = Payload(value: "codegen")
        let encoderSpy = XMLTestEncoderSpy(
            encoder: XMLEncoder(configuration: .init(rootElementName: "Payload"))
        )
        _ = try encoderSpy.encode(payload)

        XCTAssertEqual(encoderSpy.calls.count, 1)
        XCTAssertEqual(encoderSpy.calls.first?.method, .encodeData)

        let decoderSpy = XMLTestDecoderSpy()
        decoderSpy.decodeDataStub = { _, _ in payload }

        let decoded = try decoderSpy.decode(Payload.self, from: Data())
        XCTAssertEqual(decoded, payload)
        XCTAssertEqual(decoderSpy.calls.count, 1)
        XCTAssertEqual(decoderSpy.calls.first?.method, .decodeData)
    }

    func test_canonicalizerProbe_isUsableInCodeGenTests() throws {
        let canonicalize = XMLCanonicalizerContractProbe.makeDefaultCanonicalizeClosure()
        let orderResult = try XMLCanonicalizerContractProbe.probeTransformOrder(
            tokens: ["X", "Y"],
            canonicalize: canonicalize
        )

        XCTAssertEqual(orderResult.recordedTokens, ["X", "Y"])
        XCTAssertEqual(orderResult.traceValue, "XY")

        let failureResult = try XMLCanonicalizerContractProbe.probeTransformFailure(
            canonicalize: canonicalize
        )
        XCTAssertEqual(failureResult.stage, .transform)
        XCTAssertEqual(
            failureResult.code,
            XMLCanonicalizationErrorCode.transformFailed.rawValue
        )
    }
}
