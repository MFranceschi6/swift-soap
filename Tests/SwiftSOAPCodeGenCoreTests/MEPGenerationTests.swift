import Foundation
import SwiftSOAPCodeGenCore
import SwiftSOAPWSDL
import XCTest

final class MEPGenerationTests: XCTestCase {
    func test_irBuilder_detectsRequestResponse_whenBothInputAndOutputPresent() throws {
        let wsdl = """
        <wsdl:definitions xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" xmlns:tns="urn:test" targetNamespace="urn:test">
          <wsdl:message name="In"/>
          <wsdl:message name="Out"/>
          <wsdl:portType name="TestPort">
            <wsdl:operation name="Op">
              <wsdl:input message="tns:In"/>
              <wsdl:output message="tns:Out"/>
            </wsdl:operation>
          </wsdl:portType>
          <wsdl:binding name="TestBinding" type="tns:TestPort">
            <wsdl:operation name="Op"/>
          </wsdl:binding>
          <wsdl:service name="TestService">
            <wsdl:port name="TestPort" binding="tns:TestBinding"/>
          </wsdl:service>
        </wsdl:definitions>
        """
        
        let ir = try buildIR(from: wsdl)
        let op = try XCTUnwrap(ir.services.first?.ports.first?.operations.first)
        XCTAssertEqual(op.messageExchangePattern, .requestResponse)
    }

    func test_irBuilder_detectsOneWay_whenOnlyInputPresent() throws {
        let wsdl = """
        <wsdl:definitions xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" xmlns:tns="urn:test" targetNamespace="urn:test">
          <wsdl:message name="In"/>
          <wsdl:portType name="TestPort">
            <wsdl:operation name="Op">
              <wsdl:input message="tns:In"/>
            </wsdl:operation>
          </wsdl:portType>
          <wsdl:binding name="TestBinding" type="tns:TestPort">
            <wsdl:operation name="Op"/>
          </wsdl:binding>
          <wsdl:service name="TestService">
            <wsdl:port name="TestPort" binding="tns:TestBinding"/>
          </wsdl:service>
        </wsdl:definitions>
        """
        
        let ir = try buildIR(from: wsdl)
        let op = try XCTUnwrap(ir.services.first?.ports.first?.operations.first)
        XCTAssertEqual(op.messageExchangePattern, .oneWay)
    }

    func test_emitter_generatesOneWayMethod_forOneWayOperation() throws {
        let operation = OperationIR(
            swiftMethodName: "oneWayOp",
            operationContractTypeName: "OneWayOpContract",
            operationIdentifierRawValue: "oneWayOp",
            requestPayloadTypeName: "OpRequest",
            responsePayloadTypeName: "SOAPEmptyPayload",
            faultDetailTypeName: "SOAPEmptyFaultDetailPayload",
            soapAction: nil,
            bindingMetadata: .init(envelopeVersion: .soap11, style: .document, bodyUse: .literal),
            messageExchangePattern: .oneWay
        )
        
        let port = ServicePortIR(swiftTypeName: "Port", operations: [operation])
        let service = ServiceIR(swiftTypeName: "Service", ports: [port])
        
        let emitter = SwiftCodeEmitter()
        let ir = SOAPCodeGenerationIR(
            moduleName: "Test",
            generationScope: [CodeGenerationScopeOption.client],
            runtimeTargets: [CodeGenerationRuntimeTargetOption.async],
            apiStyle: .raw,
            generatedTypes: [],
            services: [service]
        )
        let syntaxProfile = CodeGenerationSyntaxProfile(
            targetSwiftVersion: .init(major: 6, minor: 0),
            useExistentialAny: true,
            useTypedThrowsAnyError: true
        )
        let artifacts = emitter.emit(ir: ir, syntaxProfile: syntaxProfile)
        let code = artifacts.first(where: { $0.fileName.contains("Client") })?.contents ?? ""
        
        XCTAssertTrue(code.contains("public func oneWayOp(request: OpRequest)"))
        XCTAssertTrue(code.contains("client.invokeOneWay(OneWayOpContract.self, request: request"))
        XCTAssertFalse(code.contains("-> SOAPOperationResponse"))
    }

    func test_emitter_generatesStandardMethod_forRequestResponseOperation() throws {
        let operation = OperationIR(
            swiftMethodName: "rrOp",
            operationContractTypeName: "RRContract",
            operationIdentifierRawValue: "rrOp",
            requestPayloadTypeName: "OpRequest",
            responsePayloadTypeName: "OpResponse",
            faultDetailTypeName: "SOAPEmptyFaultDetailPayload",
            soapAction: nil,
            bindingMetadata: .init(envelopeVersion: .soap11, style: .document, bodyUse: .literal),
            messageExchangePattern: .requestResponse
        )
        
        let port = ServicePortIR(swiftTypeName: "Port", operations: [operation])
        let service = ServiceIR(swiftTypeName: "Service", ports: [port])
        
        let emitter = SwiftCodeEmitter()
        let ir = SOAPCodeGenerationIR(
            moduleName: "Test",
            generationScope: [CodeGenerationScopeOption.client],
            runtimeTargets: [CodeGenerationRuntimeTargetOption.async],
            apiStyle: .raw,
            generatedTypes: [],
            services: [service]
        )
        let syntaxProfile = CodeGenerationSyntaxProfile(
            targetSwiftVersion: .init(major: 6, minor: 0),
            useExistentialAny: true,
            useTypedThrowsAnyError: true
        )
        let artifacts = emitter.emit(ir: ir, syntaxProfile: syntaxProfile)
        let code = artifacts.first(where: { $0.fileName.contains("Client") })?.contents ?? ""
        
        XCTAssertTrue(code.contains("public func rrOp(request: OpRequest)"))
        XCTAssertTrue(code.contains("-> SOAPOperationResponse<OpResponse, SOAPEmptyFaultDetailPayload>"))
        XCTAssertTrue(code.contains("client.invoke(RRContract.self, request: request"))
    }

    func test_irBuilder_throwsError_onUnsupportedMEP() throws {
        let wsdl = """
        <wsdl:definitions xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" xmlns:tns="urn:test" targetNamespace="urn:test">
          <wsdl:message name="Out"/>
          <wsdl:portType name="TestPort">
            <wsdl:operation name="Op">
              <wsdl:output message="tns:Out"/>
            </wsdl:operation>
          </wsdl:portType>
          <wsdl:binding name="TestBinding" type="tns:TestPort">
            <wsdl:operation name="Op"/>
          </wsdl:binding>
          <wsdl:service name="TestService">
            <wsdl:port name="TestPort" binding="tns:TestBinding"/>
          </wsdl:service>
        </wsdl:definitions>
        """
        
        XCTAssertThrowsError(try buildIR(from: wsdl)) { error in
            guard let codeGenError = error as? CodeGenError else {
                return XCTFail("Expected CodeGenError, got \(error)")
            }
            XCTAssertEqual(codeGenError.code, .invalidInput)
            XCTAssertTrue(codeGenError.message.contains("unsupported MEP"))
        }
    }

    private func buildIR(from wsdl: String) throws -> SOAPCodeGenerationIR {
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".wsdl")
        try wsdl.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        let parser = WSDLDocumentParser()
        let definition = try parser.parse(data: Data(wsdl.utf8))
        
        let builder = CodeGenerationIRBuilder()
        return try builder.build(from: definition, configuration: .init(
            wsdlPath: tempFile.path,
            moduleName: "Test",
            runtimeTargets: [CodeGenerationRuntimeTargetOption.async],
            generationScope: [CodeGenerationScopeOption.client],
            targetSwiftVersion: .init(major: 6, minor: 0)
        ))
    }
}
