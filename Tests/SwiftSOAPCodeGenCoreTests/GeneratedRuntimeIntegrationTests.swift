import Foundation
import SwiftSOAPCodeGenCore
import XCTest

// swiftlint:disable:next type_body_length
final class GeneratedRuntimeIntegrationTests: XCTestCase {
    private struct FixtureProcessFailure: LocalizedError {
        let command: String
        let output: String

        var errorDescription: String? {
            "Command failed: \(command)\n\(output)"
        }
    }

    func test_generatedRuntime_asyncAndNIO_roundtripAndFault_forRPCEncodedSOAP12() throws {
        let fileManager = FileManager.default
        let repositoryRoot = fileManager.currentDirectoryPath
        let toolchain = FixtureSwiftToolchainSupport.current
        let fixtureRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("swift-soap-generated-runtime-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: fixtureRoot) }

        try prepareFixtureLayout(at: fixtureRoot)
        try writeFixturePackageManifest(
            at: fixtureRoot,
            repositoryRoot: repositoryRoot,
            toolchain: toolchain
        )
        try writeFixtureWSDL(at: fixtureRoot)
        try writeFixtureRuntimeTests(at: fixtureRoot, toolchain: toolchain)
        try generateFixtureSources(at: fixtureRoot, toolchain: toolchain)

        let generatedFileURL = fixtureRoot
            .appendingPathComponent("Sources/GeneratedRuntime/GeneratedRuntime+GeneratedSOAP.swift")
        XCTAssertTrue(fileManager.fileExists(atPath: generatedFileURL.path))

        try runCommand(
            executable: "/usr/bin/env",
            arguments: [
                "swift",
                "test",
                "--package-path", fixtureRoot.path
            ],
            currentDirectoryURL: fixtureRoot
        )
    }

    private func prepareFixtureLayout(at fixtureRoot: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: fixtureRoot.appendingPathComponent("Fixtures", isDirectory: true),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: fixtureRoot.appendingPathComponent("Sources/GeneratedRuntime", isDirectory: true),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: fixtureRoot.appendingPathComponent("Tests/GeneratedRuntimeTests", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    private func writeFixturePackageManifest(
        at fixtureRoot: URL,
        repositoryRoot: String,
        toolchain: FixtureSwiftToolchainSupport
    ) throws {
        let escapedRepositoryRoot = repositoryRoot
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let packageIdentity = FixtureSwiftToolchainSupport.packageIdentity(forRepositoryRoot: repositoryRoot)

        let packageManifest = """
        // swift-tools-version: \(toolchain.fixtureToolsVersion)
        import PackageDescription

        let package = Package(
            name: "GeneratedRuntimeFixture",
            platforms: [
                .macOS(.v10_15)
            ],
            dependencies: [
                .package(path: "\(escapedRepositoryRoot)"),
                .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0")
            ],
            targets: [
                .target(
                    name: "GeneratedRuntime",
                    dependencies: [
                        .product(name: "SwiftSOAPCore", package: "\(packageIdentity)"),
                        .product(name: "SwiftSOAPClientAsync", package: "\(packageIdentity)"),
                        .product(name: "SwiftSOAPServerAsync", package: "\(packageIdentity)"),
                        .product(name: "SwiftSOAPClientNIO", package: "\(packageIdentity)"),
                        .product(name: "SwiftSOAPServerNIO", package: "\(packageIdentity)"),
                        .product(name: "NIOCore", package: "swift-nio")
                    ]
                ),
                .testTarget(
                    name: "GeneratedRuntimeTests",
                    dependencies: [
                        "GeneratedRuntime",
                        .product(name: "NIOPosix", package: "swift-nio")
                    ]
                )
            ]
        )
        """

        try packageManifest.write(
            to: fixtureRoot.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func writeFixtureWSDL(at fixtureRoot: URL) throws {
        let wsdl = """
        <wsdl:definitions
            xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
            xmlns:soap12="http://schemas.xmlsoap.org/wsdl/soap12/"
            xmlns:tns="urn:matrix"
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:matrix"
            name="MatrixService">
          <wsdl:types>
            <xsd:schema targetNamespace="urn:matrix">
              <xsd:complexType name="MatrixPayload">
                <xsd:sequence>
                  <xsd:element name="value" type="xsd:string"/>
                </xsd:sequence>
              </xsd:complexType>
            </xsd:schema>
          </wsdl:types>
          <wsdl:message name="InputMessage">
            <wsdl:part name="value" type="xsd:string"/>
          </wsdl:message>
          <wsdl:message name="OutputMessage">
            <wsdl:part name="value" type="xsd:string"/>
          </wsdl:message>
          <wsdl:message name="FaultMessage">
            <wsdl:part name="reason" type="xsd:string"/>
          </wsdl:message>
          <wsdl:portType name="MatrixPortType">
            <wsdl:operation name="Transform">
              <wsdl:input message="tns:InputMessage"/>
              <wsdl:output message="tns:OutputMessage"/>
              <wsdl:fault name="Fault" message="tns:FaultMessage"/>
            </wsdl:operation>
          </wsdl:portType>
          <wsdl:binding name="MatrixBinding" type="tns:MatrixPortType">
            <soap12:binding style="rpc" transport="http://schemas.xmlsoap.org/soap/http"/>
            <wsdl:operation name="Transform">
              <soap12:operation soapAction="urn:transform" style="rpc"/>
              <wsdl:input><soap12:body use="encoded"/></wsdl:input>
              <wsdl:output><soap12:body use="encoded"/></wsdl:output>
            </wsdl:operation>
          </wsdl:binding>
          <wsdl:service name="MatrixService">
            <wsdl:port name="MatrixPort" binding="tns:MatrixBinding"/>
          </wsdl:service>
        </wsdl:definitions>
        """

        try wsdl.write(
            to: fixtureRoot.appendingPathComponent("Fixtures/service.wsdl"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func generateFixtureSources(at fixtureRoot: URL, toolchain: FixtureSwiftToolchainSupport) throws {
        let configuration = CodeGenConfiguration(
            wsdlPath: "Fixtures/service.wsdl",
            moduleName: "GeneratedRuntime",
            outputMode: .export,
            buildOutputDirectory: ".build/swift-soap-codegen",
            exportOutputDirectory: "Sources/GeneratedRuntime",
            runtimeTargets: [.async, .nio],
            generationScope: [.client, .server],
            targetSwiftVersion: toolchain.codeGenTargetSwiftVersion,
            syntaxFeatures: [:],
            apiStyle: .raw
        )

        let generator = CodeGenerator()
        let artifacts = try generator.generate(configuration: configuration, packageRootPath: fixtureRoot.path)
        try generator.writeArtifacts(artifacts, configuration: configuration, packageRootPath: fixtureRoot.path)
    }

    // swiftlint:disable:next function_body_length
    private func writeFixtureRuntimeTests(at fixtureRoot: URL, toolchain: FixtureSwiftToolchainSupport) throws {
        let asyncThrowsClause = toolchain.asyncThrowsClause
        let tests = #"""
        import Foundation
        import NIOCore
        import NIOPosix
        import SwiftSOAPClientAsync
        import SwiftSOAPClientNIO
        import SwiftSOAPCore
        import SwiftSOAPServerAsync
        import SwiftSOAPServerNIO
        import XCTest
        @testable import GeneratedRuntime

        final class GeneratedRuntimeRoundtripTests: XCTestCase {
            func test_roundtrip_successAndFault_forAsyncAndNIO() async throws {
                XCTAssertEqual(MatrixServiceMatrixPortTransformOperation.bindingMetadata.envelopeVersion, .soap12)
                XCTAssertEqual(MatrixServiceMatrixPortTransformOperation.bindingMetadata.style, .rpc)
                XCTAssertEqual(MatrixServiceMatrixPortTransformOperation.bindingMetadata.bodyUse, .encoded)

                let endpointURL = try XCTUnwrap(URL(string: "https://example.com/soap"))

                let asyncServer = AsyncLoopbackServer()
                let asyncRegistrar = MatrixServiceMatrixPortAsyncServerRegistrar(server: asyncServer)
                try await asyncRegistrar.register(implementation: AsyncServiceImplementation())
                try await asyncServer.start()

                let wireCodec = SOAPXMLWireCodec()
                let asyncClient = MatrixServiceMatrixPortAsyncClient(
                    client: SOAPTransportClientAsync(
                        transport: AsyncLoopbackTransport(server: asyncServer, codec: wireCodec),
                        wireCodec: wireCodec
                    ),
                    endpointURL: endpointURL
                )

                let asyncSuccess = try await asyncClient.transform(request: InputMessagePayload(value: "ok"))
                switch asyncSuccess {
                case .success(let payload):
                    XCTAssertEqual(payload.value, "pong:ok")
                case .fault:
                    XCTFail("Expected async success response.")
                }

                let asyncFault = try await asyncClient.transform(request: InputMessagePayload(value: "fault"))
                switch asyncFault {
                case .success:
                    XCTFail("Expected async fault response.")
                case .fault(let fault):
                    XCTAssertEqual(fault.faultCode, .server)
                    XCTAssertEqual(fault.detail?.reason, "simulated-fault")
                }

                try await asyncServer.stop()

                let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
                addTeardownBlock {
                    try await eventLoopGroup.shutdownGracefully()
                }
                let eventLoop = eventLoopGroup.next()
                let nioServer = NIOLoopbackServer()
                let nioRegistrar = MatrixServiceMatrixPortNIOServerRegistrar(server: nioServer)
                nioRegistrar.register(implementation: NIOServiceImplementation())
                try await nioServer.start(on: eventLoop).get()

                let nioClient = MatrixServiceMatrixPortNIOClient(
                    client: SOAPTransportClientNIO(
                        transport: NIOLoopbackTransport(server: nioServer, codec: wireCodec, eventLoop: eventLoop),
                        wireCodec: wireCodec
                    ),
                    endpointURL: endpointURL
                )

                let nioSuccess = try await nioClient.transform(
                    request: InputMessagePayload(value: "ok"),
                    on: eventLoop
                ).get()
                switch nioSuccess {
                case .success(let payload):
                    XCTAssertEqual(payload.value, "pong:ok")
                case .fault:
                    XCTFail("Expected NIO success response.")
                }

                let nioFault = try await nioClient.transform(
                    request: InputMessagePayload(value: "fault"),
                    on: eventLoop
                ).get()
                switch nioFault {
                case .success:
                    XCTFail("Expected NIO fault response.")
                case .fault(let fault):
                    XCTAssertEqual(fault.faultCode, .server)
                    XCTAssertEqual(fault.detail?.reason, "simulated-fault")
                }

                try await nioServer.stop(on: eventLoop).get()
            }
        }

        private struct AsyncServiceImplementation: MatrixServiceMatrixPortAsyncService {
            func transform(
                request: InputMessagePayload
            ) async __ASYNC_THROWS_CLAUSE__ -> SOAPOperationResponse<
                OutputMessagePayload,
                FaultMessageFaultDetail
            > {
                if request.value == "fault" {
                    let fault = try SOAPFault<FaultMessageFaultDetail>(
                        faultCode: .server,
                        faultString: "simulated server fault",
                        detail: FaultMessageFaultDetail(reason: "simulated-fault")
                    )
                    return .fault(fault)
                }

                return .success(OutputMessagePayload(value: "pong:\(request.value ?? "nil")"))
            }
        }

        private struct NIOServiceImplementation: MatrixServiceMatrixPortNIOService {
            func transform(
                request: InputMessagePayload,
                on eventLoop: EventLoop
            ) -> EventLoopFuture<SOAPOperationResponse<OutputMessagePayload, FaultMessageFaultDetail>> {
                if request.value == "fault" {
                    do {
                        let fault = try SOAPFault<FaultMessageFaultDetail>(
                            faultCode: .server,
                            faultString: "simulated server fault",
                            detail: FaultMessageFaultDetail(reason: "simulated-fault")
                        )
                        return eventLoop.makeSucceededFuture(.fault(fault))
                    } catch {
                        return eventLoop.makeFailedFuture(error)
                    }
                }

                return eventLoop.makeSucceededFuture(
                    .success(OutputMessagePayload(value: "pong:\(request.value ?? "nil")"))
                )
            }
        }

        private actor AsyncLoopbackServer: SOAPServerAsync {
            private typealias ErasedHandler = @Sendable (Any) async __ASYNC_THROWS_CLAUSE__ -> Any

            private var handlers: [String: ErasedHandler] = [:]

            func register<Operation: SOAPOperationContract>(
                _ operation: Operation.Type,
                handler: @escaping SOAPAsyncOperationHandler<Operation>
            ) async __ASYNC_THROWS_CLAUSE__ {
                handlers[operation.operationIdentifier.rawValue] = { request in
                    guard let typedRequest = request as? Operation.RequestPayload else {
                        throw SOAPCoreError.invalidPayload(message: "Invalid async request payload for operation.")
                    }
                    return try await handler(typedRequest)
                }
            }

            func start() async __ASYNC_THROWS_CLAUSE__ {}
            func stop() async __ASYNC_THROWS_CLAUSE__ {}

            func dispatch<Operation: SOAPOperationContract>(
                _ operation: Operation.Type,
                request: Operation.RequestPayload
            ) async __ASYNC_THROWS_CLAUSE__ -> SOAPOperationResponse<
                Operation.ResponsePayload,
                Operation.FaultDetailPayload
            > {
                guard let handler = handlers[operation.operationIdentifier.rawValue] else {
                    throw SOAPCoreError.invalidPayload(message: "Missing async operation handler.")
                }

                let response = try await handler(request)
                guard let typedResponse = response as? SOAPOperationResponse<
                    Operation.ResponsePayload,
                    Operation.FaultDetailPayload
                > else {
                    throw SOAPCoreError.invalidPayload(message: "Invalid async operation response payload.")
                }

                return typedResponse
            }
        }

        private struct AsyncLoopbackTransport: SOAPClientTransport {
            let server: AsyncLoopbackServer
            let codec: SOAPXMLWireCodec

            func send(
                _ requestXMLData: Data,
                to endpointURL: URL,
                soapAction: String?
            ) async __ASYNC_THROWS_CLAUSE__ -> Data {
                _ = endpointURL
                _ = soapAction

                let request = try codec.decodeRequestEnvelope(
                    operation: MatrixServiceMatrixPortTransformOperation.self,
                    from: requestXMLData
                )
                let response = try await server.dispatch(
                    MatrixServiceMatrixPortTransformOperation.self,
                    request: request
                )
                return try codec.encodeResponseEnvelope(
                    operation: MatrixServiceMatrixPortTransformOperation.self,
                    response: response
                )
            }
        }

        private final class NIOLoopbackServer: SOAPServerNIO, @unchecked Sendable {
            typealias ErasedHandler = (Any, EventLoop) -> EventLoopFuture<Any>

            private var handlers: [String: ErasedHandler] = [:]

            func register<Operation: SOAPOperationContract>(
                _ operation: Operation.Type,
                handler: @escaping SOAPNIOOperationHandler<Operation>
            ) {
                handlers[operation.operationIdentifier.rawValue] = { request, eventLoop in
                    guard let typedRequest = request as? Operation.RequestPayload else {
                        return eventLoop.makeFailedFuture(
                            SOAPCoreError.invalidPayload(message: "Invalid NIO request payload for operation.")
                        )
                    }

                    return handler(typedRequest, eventLoop).flatMapThrowing { response in
                        response as Any
                    }
                }
            }

            func start(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
                eventLoop.makeSucceededFuture(())
            }

            func stop(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
                eventLoop.makeSucceededFuture(())
            }

            func dispatch<Operation: SOAPOperationContract>(
                _ operation: Operation.Type,
                request: Operation.RequestPayload,
                on eventLoop: EventLoop
            ) -> EventLoopFuture<SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>> {
                guard let handler = handlers[operation.operationIdentifier.rawValue] else {
                    return eventLoop.makeFailedFuture(
                        SOAPCoreError.invalidPayload(message: "Missing NIO operation handler.")
                    )
                }

                return handler(request, eventLoop).flatMapThrowing { response in
                    guard let typedResponse = response as? SOAPOperationResponse<
                        Operation.ResponsePayload,
                        Operation.FaultDetailPayload
                    > else {
                        throw SOAPCoreError.invalidPayload(message: "Invalid NIO operation response payload.")
                    }
                    return typedResponse
                }
            }
        }

        private struct NIOLoopbackTransport: SOAPClientTransport {
            let server: NIOLoopbackServer
            let codec: SOAPXMLWireCodec
            let eventLoop: EventLoop

            func send(
                _ requestXMLData: Data,
                to endpointURL: URL,
                soapAction: String?
            ) async __ASYNC_THROWS_CLAUSE__ -> Data {
                _ = endpointURL
                _ = soapAction

                let request = try codec.decodeRequestEnvelope(
                    operation: MatrixServiceMatrixPortTransformOperation.self,
                    from: requestXMLData
                )
                let response = try await server.dispatch(
                    MatrixServiceMatrixPortTransformOperation.self,
                    request: request,
                    on: eventLoop
                ).get()
                return try codec.encodeResponseEnvelope(
                    operation: MatrixServiceMatrixPortTransformOperation.self,
                    response: response
                )
            }
        }
        """#
            .replacingOccurrences(of: "__ASYNC_THROWS_CLAUSE__", with: asyncThrowsClause)

        try tests.write(
            to: fixtureRoot.appendingPathComponent("Tests/GeneratedRuntimeTests/GeneratedRuntimeRoundtripTests.swift"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func runCommand(
        executable: String,
        arguments: [String],
        currentDirectoryURL: URL
    ) throws {
        let logURL = currentDirectoryURL.appendingPathComponent("command-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let logHandle = try FileHandle(forWritingTo: logURL)
        defer {
            try? logHandle.close()
            try? FileManager.default.removeItem(at: logURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        process.standardOutput = logHandle
        process.standardError = logHandle
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let output = try String(contentsOf: logURL, encoding: .utf8)
            let command = ([executable] + arguments).joined(separator: " ")
            throw FixtureProcessFailure(command: command, output: output)
        }
    }
}
