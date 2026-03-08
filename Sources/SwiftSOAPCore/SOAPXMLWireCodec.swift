import SwiftSOAPXML

public struct SOAPXMLWireCodec: Sendable {
    public struct Configuration: Sendable {
        public let requestEncoder: XMLEncoder
        public let responseEncoder: XMLEncoder
        public let requestDecoder: XMLDecoder
        public let responseDecoder: XMLDecoder

        public init(
            requestEncoder: XMLEncoder = XMLEncoder(),
            responseEncoder: XMLEncoder = XMLEncoder(),
            requestDecoder: XMLDecoder = XMLDecoder(),
            responseDecoder: XMLDecoder = XMLDecoder()
        ) {
            self.requestEncoder = requestEncoder
            self.responseEncoder = responseEncoder
            self.requestDecoder = requestDecoder
            self.responseDecoder = responseDecoder
        }
    }

    public let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
}
