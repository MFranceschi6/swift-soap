import Foundation
import SwiftSOAPCore
import XCTest

final class SOAPModelTests: XCTestCase {
    private struct WeatherRequest: SOAPBodyPayload, Equatable {
        let city: String
        let unit: String
    }

    private struct TrackingHeader: SOAPHeaderPayload, Equatable {
        let trackingID: String
        let correlationID: String
    }

    private struct MissingParameterDetail: SOAPFaultDetailPayload, Equatable {
        let missingField: String
    }

    private struct FaultCodeMapping {
        let rawValue: String
        let expectedCode: SOAPFaultCode
        let canonicalRawValue: String
    }

    func test_emptyPayloadMarkers_areConstructible() {
        _ = SOAPEmptyPayload()
        _ = SOAPEmptyHeaderPayload()
        _ = SOAPEmptyFaultDetailPayload()
    }

    func test_faultCodeInit_withQName_mapsToStandardCode() throws {
        let code = try SOAPFaultCode(rawValue: "SOAP-ENV:Client")
        XCTAssertEqual(code, .client)
        XCTAssertEqual(code.rawValue, "Client")
    }

    func test_faultCodeInit_withKnownValues_mapsToEnumCases() throws {
        let knownMappings: [FaultCodeMapping] = [
            .init(rawValue: "VersionMismatch", expectedCode: .versionMismatch, canonicalRawValue: "VersionMismatch"),
            .init(rawValue: "MustUnderstand", expectedCode: .mustUnderstand, canonicalRawValue: "MustUnderstand"),
            .init(rawValue: "Server", expectedCode: .server, canonicalRawValue: "Server"),
            .init(rawValue: "Sender", expectedCode: .sender, canonicalRawValue: "Sender"),
            .init(rawValue: "Receiver", expectedCode: .receiver, canonicalRawValue: "Receiver"),
            .init(
                rawValue: "DataEncodingUnknown",
                expectedCode: .dataEncodingUnknown,
                canonicalRawValue: "DataEncodingUnknown"
            )
        ]

        for mapping in knownMappings {
            let code = try SOAPFaultCode(rawValue: mapping.rawValue)
            XCTAssertEqual(code, mapping.expectedCode)
            XCTAssertEqual(code.rawValue, mapping.canonicalRawValue)
        }
    }

    func test_faultCodeInit_withUnknownCode_preservesRawValue() throws {
        let code = try SOAPFaultCode(rawValue: "Vendor:RateLimitExceeded")
        XCTAssertEqual(code, .custom("Vendor:RateLimitExceeded"))
        XCTAssertEqual(code.rawValue, "Vendor:RateLimitExceeded")
    }

    func test_envelopeNamespaceInit_withSOAP12URI_mapsToSOAP12() throws {
        let namespace = try SOAPEnvelopeNamespace(uri: "http://www.w3.org/2003/05/soap-envelope")
        XCTAssertEqual(namespace, .soap12)
    }

    func test_faultInit_withEmptyFaultCode_throwsInvalidFault() {
        XCTAssertThrowsError(
            try SOAPFault<SOAPEmptyFaultDetailPayload>(faultCode: " ", faultString: "Server error")
        ) { error in
            guard case SOAPCoreError.invalidFault = error else {
                return XCTFail("Expected invalidFault, got: \(error)")
            }
        }
    }

    func test_faultInit_withEmptyFaultString_throwsInvalidFault() {
        XCTAssertThrowsError(
            try SOAPFault<SOAPEmptyFaultDetailPayload>(faultCode: "Server", faultString: " ")
        ) { error in
            guard case SOAPCoreError.invalidFault = error else {
                return XCTFail("Expected invalidFault, got: \(error)")
            }
        }
    }

    func test_headerInit_withTypedPayload_preservesData() {
        let header = SOAPHeader(payload: TrackingHeader(trackingID: "abc", correlationID: "def"))

        XCTAssertEqual(header.payload.trackingID, "abc")
        XCTAssertEqual(header.payload.correlationID, "def")
    }

    func test_bodyInit_withTypedPayload_storesPayloadContent() {
        struct EmptyRequest: SOAPBodyPayload, Equatable {}
        let body = SOAPBody<EmptyRequest, SOAPEmptyFaultDetailPayload>(payload: EmptyRequest())

        guard case .payload(let payload) = body.content else {
            return XCTFail("Expected payload content.")
        }
        XCTAssertEqual(payload, EmptyRequest())
    }

    func test_bodyInit_withFault_storesFaultContent() throws {
        let fault = try SOAPFault<SOAPEmptyFaultDetailPayload>(faultCode: "Server", faultString: "Internal error")
        let body = SOAPBody<WeatherRequest, SOAPEmptyFaultDetailPayload>(fault: fault)

        guard case .fault(let storedFault) = body.content else {
            return XCTFail("Expected fault content.")
        }
        XCTAssertEqual(storedFault, fault)
    }

    func test_bodyInit_withPayload_exposesPayloadAndNotFault() throws {
        let request = WeatherRequest(city: "Rome", unit: "celsius")
        let body = SOAPBody<WeatherRequest, SOAPEmptyFaultDetailPayload>(payload: request)

        XCTAssertEqual(body.payload, request)
        XCTAssertNil(body.fault)
    }

    func test_bodyInit_withFault_exposesFaultAndNotPayload() throws {
        let fault = try SOAPFault<SOAPEmptyFaultDetailPayload>(faultCode: "Server", faultString: "Internal error")
        let body = SOAPBody<WeatherRequest, SOAPEmptyFaultDetailPayload>(fault: fault)

        XCTAssertEqual(body.fault, fault)
        XCTAssertNil(body.payload)
    }

    func test_envelopeInit_withEmptyNamespace_throwsInvalidEnvelope() throws {
        let body = SOAPBody<WeatherRequest, SOAPEmptyFaultDetailPayload>(
            payload: WeatherRequest(city: "Rome", unit: "celsius")
        )

        XCTAssertThrowsError(
            try SOAPEnvelope<WeatherRequest, SOAPEmptyHeaderPayload, SOAPEmptyFaultDetailPayload>(
                namespaceURI: " ",
                body: body
            )
        ) { error in
            guard case SOAPCoreError.invalidEnvelope = error else {
                return XCTFail("Expected invalidEnvelope, got: \(error)")
            }
        }
    }

    func test_envelopeInit_withPayload_usesDefaultSOAP11Namespace() throws {
        let request = WeatherRequest(city: "Rome", unit: "celsius")
        let envelope = SOAPEnvelope<WeatherRequest, SOAPEmptyHeaderPayload, SOAPEmptyFaultDetailPayload>(
            payload: request
        )

        XCTAssertEqual(
            envelope.namespaceURI,
            SOAPEnvelope<WeatherRequest, SOAPEmptyHeaderPayload, SOAPEmptyFaultDetailPayload>.soap11NamespaceURI
        )
        XCTAssertEqual(envelope.namespace, .soap11)
        guard case .payload(let payload) = envelope.body.content else {
            return XCTFail("Expected payload content.")
        }
        XCTAssertEqual(payload, request)
    }

    func test_envelopeInit_withBodyAndNamespaceURI_mapsNamespace() throws {
        let body = SOAPBody<WeatherRequest, SOAPEmptyFaultDetailPayload>(
            payload: WeatherRequest(city: "Rome", unit: "celsius")
        )
        let envelope = try SOAPEnvelope<WeatherRequest, SOAPEmptyHeaderPayload, SOAPEmptyFaultDetailPayload>(
            namespaceURI: SOAPEnvelopeNamespace.soap12.uri,
            body: body
        )

        XCTAssertEqual(envelope.namespace, .soap12)
        XCTAssertEqual(envelope.namespaceURI, SOAPEnvelopeNamespace.soap12.uri)
    }

    func test_envelopeInit_withPayloadAndNamespaceURI_mapsCustomNamespace() throws {
        let request = WeatherRequest(city: "Rome", unit: "celsius")
        let envelope = try SOAPEnvelope<WeatherRequest, SOAPEmptyHeaderPayload, SOAPEmptyFaultDetailPayload>(
            payload: request,
            namespaceURI: "urn:custom-soap"
        )

        XCTAssertEqual(envelope.namespace, .custom("urn:custom-soap"))
        XCTAssertEqual(envelope.namespaceURI, "urn:custom-soap")
    }

    func test_headerCodableRoundTrip_preservesTypedPayload() throws {
        let header = SOAPHeader(payload: TrackingHeader(trackingID: "abc", correlationID: "def"))
        let encodedHeader = try JSONEncoder().encode(header)
        let decodedHeader = try JSONDecoder().decode(SOAPHeader<TrackingHeader>.self, from: encodedHeader)

        XCTAssertEqual(decodedHeader, header)
    }

    func test_envelopeInit_withFault_andCustomNamespace_succeeds() throws {
        let fault = try SOAPFault<MissingParameterDetail>(
            faultCode: "Client",
            faultString: "Missing parameter",
            faultActor: "client.example",
            detail: MissingParameterDetail(missingField: "city")
        )
        let header = SOAPHeader(payload: TrackingHeader(trackingID: "123", correlationID: "456"))
        let envelope = try SOAPEnvelope<WeatherRequest, TrackingHeader, MissingParameterDetail>(
            fault: fault,
            namespaceURI: "urn:soap-custom",
            header: header
        )

        XCTAssertEqual(envelope.namespaceURI, "urn:soap-custom")
        XCTAssertNotNil(envelope.header)
        XCTAssertEqual(envelope.body.fault, fault)
    }

    func test_envelopeInit_withFaultAndNamespaceEnum_succeeds() throws {
        let fault = try SOAPFault<MissingParameterDetail>(
            faultCode: .receiver,
            faultString: "Receiver error",
            detail: MissingParameterDetail(missingField: "city")
        )
        let envelope = SOAPEnvelope<WeatherRequest, SOAPEmptyHeaderPayload, MissingParameterDetail>(
            fault: fault,
            namespace: .soap12
        )

        XCTAssertEqual(envelope.namespace, .soap12)
        XCTAssertEqual(envelope.body.fault, fault)
    }

    func test_envelopeConvenienceInit_withPayloadAndNamespaceURI_succeeds() throws {
        let request = WeatherRequest(city: "Rome", unit: "celsius")
        let envelope = try SOAPEnvelope<WeatherRequest, SOAPEmptyHeaderPayload, SOAPEmptyFaultDetailPayload>(
            payload: request,
            namespaceURI: SOAPEnvelopeNamespace.soap11.uri
        )

        XCTAssertEqual(envelope.namespace, .soap11)
    }

    func test_envelopeConvenienceInit_withFaultAndNamespaceURI_succeeds() throws {
        let fault = try SOAPFault<SOAPEmptyFaultDetailPayload>(
            faultCode: .server,
            faultString: "Server error"
        )
        let envelope = try SOAPEnvelope<WeatherRequest, SOAPEmptyHeaderPayload, SOAPEmptyFaultDetailPayload>(
            fault: fault,
            namespaceURI: SOAPEnvelopeNamespace.soap11.uri
        )

        XCTAssertEqual(envelope.namespace, .soap11)
        XCTAssertEqual(envelope.body.fault, fault)
    }

    func test_envelopeCodableRoundTrip_preservesTypedPayload() throws {
        let request = WeatherRequest(city: "Rome", unit: "celsius")
        let envelope = SOAPEnvelope<WeatherRequest, SOAPEmptyHeaderPayload, SOAPEmptyFaultDetailPayload>(
            payload: request
        )

        let encodedEnvelope = try JSONEncoder().encode(envelope)
        let decodedEnvelope = try JSONDecoder().decode(
            SOAPEnvelope<WeatherRequest, SOAPEmptyHeaderPayload, SOAPEmptyFaultDetailPayload>.self,
            from: encodedEnvelope
        )

        XCTAssertEqual(decodedEnvelope, envelope)
        XCTAssertEqual(decodedEnvelope.body.payload, request)
    }

    func test_faultCodableRoundTrip_preservesTypedDetail() throws {
        let fault = try SOAPFault<MissingParameterDetail>(
            faultCode: .client,
            faultString: "Missing parameter",
            detail: MissingParameterDetail(missingField: "city")
        )

        let encodedFault = try JSONEncoder().encode(fault)
        let decodedFault = try JSONDecoder().decode(SOAPFault<MissingParameterDetail>.self, from: encodedFault)

        XCTAssertEqual(decodedFault, fault)
        XCTAssertEqual(decodedFault.detail?.missingField, "city")
    }

    func test_soapOperationContract_defaultSoapAction_isNil() {
        // Covers SOAPOperationContract+Defaults.swift: default soapAction extension returns nil
        struct DummyRequest: SOAPBodyPayload {}
        struct DummyResponse: SOAPBodyPayload {}
        struct DummyFaultDetail: SOAPFaultDetailPayload {}
        struct DummyOperation: SOAPOperationContract {
            typealias RequestPayload = DummyRequest
            typealias ResponsePayload = DummyResponse
            typealias FaultDetailPayload = DummyFaultDetail
            static let operationIdentifier = SOAPOperationIdentifier(rawValue: "Dummy")
        }
        XCTAssertNil(DummyOperation.soapAction)
    }

    // MARK: - SOAPEnvelope.init(payload:namespaceURI:) coverage

    func test_soapEnvelope_initPayloadNamespaceURI_soap11_succeeds() throws {
        // Covers SOAPEnvelope.init(payload:namespaceURI:) typed-throw overload (lines 66, 68)
        let payload = WeatherRequest(city: "Rome", unit: "C")
        let soap11URI = SOAPEnvelope<
            WeatherRequest,
            SOAPEmptyHeaderPayload,
            SOAPEmptyFaultDetailPayload
        >.soap11NamespaceURI
        let envelope = try SOAPEnvelope<
            WeatherRequest,
            SOAPEmptyHeaderPayload,
            SOAPEmptyFaultDetailPayload
        >(payload: payload, namespaceURI: soap11URI)
        XCTAssertEqual(envelope.namespace, .soap11)
        XCTAssertEqual(envelope.body.payload?.city, "Rome")
    }

    func test_soapEnvelope_initPayloadNamespaceURI_emptyURI_throws() {
        let payload = WeatherRequest(city: "Rome", unit: "C")
        XCTAssertThrowsError(
            try SOAPEnvelope<WeatherRequest, SOAPEmptyHeaderPayload, SOAPEmptyFaultDetailPayload>(
                payload: payload,
                namespaceURI: ""
            )
        )
    }
}
