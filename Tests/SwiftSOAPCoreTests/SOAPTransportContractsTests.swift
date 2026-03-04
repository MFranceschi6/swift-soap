import Foundation
import SwiftSOAPCore
import XCTest

final class SOAPTransportContractsTests: XCTestCase {
    func test_clientTransportContract_returnsConfiguredResponse() async throws {
        let responseXMLData = Data("<Envelope><Body><Ok/></Body></Envelope>".utf8)
        let transport = StubSOAPClientTransport(responseXMLData: responseXMLData)

        let endpointURL = try XCTUnwrap(URL(string: "https://example.com/soap"))
        let requestXMLData = Data("<Envelope><Body><Ping/></Body></Envelope>".utf8)
        let receivedResponseXMLData = try await transport.send(
            requestXMLData,
            to: endpointURL,
            soapAction: "PingAction"
        )

        XCTAssertEqual(receivedResponseXMLData, responseXMLData)
    }

    func test_serverTransportContract_invokesRegisteredHandler() async throws {
        let transport = StubSOAPServerTransport()
        let requestXMLData = Data("<Envelope><Body><Ping/></Body></Envelope>".utf8)
        let responseXMLData = Data("<Envelope><Body><Pong/></Body></Envelope>".utf8)

        try await transport.start { receivedRequestXMLData in
            XCTAssertEqual(receivedRequestXMLData, requestXMLData)
            return responseXMLData
        }

        let receivedResponseXMLData = try await transport.handle(requestXMLData)
        XCTAssertEqual(receivedResponseXMLData, responseXMLData)
    }
}

private struct StubSOAPClientTransport: SOAPClientTransport {
    let responseXMLData: Data

    func send(_ requestXMLData: Data, to endpointURL: URL, soapAction: String?) async throws -> Data {
        _ = requestXMLData
        _ = endpointURL
        _ = soapAction
        return responseXMLData
    }
}

private actor StubSOAPServerTransport: SOAPServerTransport {
    private var handler: SOAPRequestHandler?

    func start(handler: @escaping SOAPRequestHandler) async throws {
        self.handler = handler
    }

    func stop() async throws {
        handler = nil
    }

    func handle(_ requestXMLData: Data) async throws -> Data {
        guard let handler else {
            throw SOAPCoreError.invalidBodyConfiguration(message: "Handler was not configured.")
        }
        return try await handler(requestXMLData)
    }
}
