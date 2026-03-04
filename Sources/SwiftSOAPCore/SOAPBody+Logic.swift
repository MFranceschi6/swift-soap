public extension SOAPBody {
    init(payload: Payload) {
        self.content = .payload(payload)
    }

    init(fault: SOAPFault<FaultDetail>) {
        self.content = .fault(fault)
    }

    var payload: Payload? {
        guard case .payload(let payload) = content else {
            return nil
        }
        return payload
    }

    var fault: SOAPFault<FaultDetail>? {
        guard case .fault(let fault) = content else {
            return nil
        }
        return fault
    }
}
