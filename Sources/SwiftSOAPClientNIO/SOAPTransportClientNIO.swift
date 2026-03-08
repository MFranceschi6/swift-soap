import SwiftSOAPCore

public struct SOAPTransportClientNIO: Sendable {
    public let transport: any SOAPClientTransport
    public let wireCodec: SOAPXMLWireCodec

    public init(
        transport: any SOAPClientTransport,
        wireCodec: SOAPXMLWireCodec = SOAPXMLWireCodec()
    ) {
        self.transport = transport
        self.wireCodec = wireCodec
    }
}
