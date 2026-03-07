public struct WSDLDefinition: Sendable, Equatable {
    public let name: String?
    public let targetNamespace: String?
    public let messages: [Message]
    public let portTypes: [PortType]
    public let bindings: [Binding]
    public let services: [Service]

    public init(
        name: String?,
        targetNamespace: String?,
        messages: [Message],
        portTypes: [PortType],
        bindings: [Binding],
        services: [Service]
    ) {
        self.name = name
        self.targetNamespace = targetNamespace
        self.messages = messages
        self.portTypes = portTypes
        self.bindings = bindings
        self.services = services
    }
}

extension WSDLDefinition {
    public struct Message: Sendable, Equatable {
        public let name: String
        public let parts: [Part]

        public init(name: String, parts: [Part]) {
            self.name = name
            self.parts = parts
        }
    }

    public struct Part: Sendable, Equatable {
        public let name: String
        public let elementName: String?
        public let typeName: String?

        public init(name: String, elementName: String?, typeName: String?) {
            self.name = name
            self.elementName = elementName
            self.typeName = typeName
        }
    }

    public struct PortType: Sendable, Equatable {
        public let name: String
        public let operations: [Operation]

        public init(name: String, operations: [Operation]) {
            self.name = name
            self.operations = operations
        }
    }

    public struct Operation: Sendable, Equatable {
        public let name: String
        public let inputMessageName: String?
        public let outputMessageName: String?
        public let faults: [Fault]

        public init(name: String, inputMessageName: String?, outputMessageName: String?, faults: [Fault]) {
            self.name = name
            self.inputMessageName = inputMessageName
            self.outputMessageName = outputMessageName
            self.faults = faults
        }
    }

    public struct Fault: Sendable, Equatable {
        public let name: String
        public let messageName: String?

        public init(name: String, messageName: String?) {
            self.name = name
            self.messageName = messageName
        }
    }

    public struct Binding: Sendable, Equatable {
        public let name: String
        public let typeName: String?
        public let style: String?
        public let operations: [BindingOperation]

        public init(name: String, typeName: String?, style: String?, operations: [BindingOperation]) {
            self.name = name
            self.typeName = typeName
            self.style = style
            self.operations = operations
        }
    }

    public struct BindingOperation: Sendable, Equatable {
        public let name: String
        public let soapAction: String?

        public init(name: String, soapAction: String?) {
            self.name = name
            self.soapAction = soapAction
        }
    }

    public struct Service: Sendable, Equatable {
        public let name: String
        public let ports: [ServicePort]

        public init(name: String, ports: [ServicePort]) {
            self.name = name
            self.ports = ports
        }
    }

    public struct ServicePort: Sendable, Equatable {
        public let name: String
        public let bindingName: String?
        public let address: String?

        public init(name: String, bindingName: String?, address: String?) {
            self.name = name
            self.bindingName = bindingName
            self.address = address
        }
    }
}
