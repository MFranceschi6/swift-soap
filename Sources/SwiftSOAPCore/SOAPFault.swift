import Foundation

public struct SOAPFault<DetailPayload: SOAPFaultDetailPayload>: Sendable, Codable {
    public let faultCode: SOAPFaultCode
    public let faultString: String
    public let faultActor: String?
    public let detail: DetailPayload?

    #if swift(>=6.0)
    public init(
        faultCode: SOAPFaultCode,
        faultString: String,
        faultActor: String? = nil,
        detail: DetailPayload? = nil
    ) throws(SOAPCoreError) {
        let cleanedFaultString = faultString.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedFaultActor = faultActor?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedFaultString.isEmpty else {
            throw SOAPCoreError.invalidFault(message: "Fault string cannot be empty.")
        }

        self.faultCode = faultCode
        self.faultString = cleanedFaultString
        self.faultActor = (cleanedFaultActor?.isEmpty == true) ? nil : cleanedFaultActor
        self.detail = detail
    }

    public init(
        faultCode: String,
        faultString: String,
        faultActor: String? = nil,
        detail: DetailPayload? = nil
    ) throws(SOAPCoreError) {
        let parsedFaultCode = try SOAPFaultCode(rawValue: faultCode)
        try self.init(
            faultCode: parsedFaultCode,
            faultString: faultString,
            faultActor: faultActor,
            detail: detail
        )
    }
    #else
    public init(
        faultCode: SOAPFaultCode,
        faultString: String,
        faultActor: String? = nil,
        detail: DetailPayload? = nil
    ) throws {
        let cleanedFaultString = faultString.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedFaultActor = faultActor?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedFaultString.isEmpty else {
            throw SOAPCoreError.invalidFault(message: "Fault string cannot be empty.")
        }

        self.faultCode = faultCode
        self.faultString = cleanedFaultString
        self.faultActor = (cleanedFaultActor?.isEmpty == true) ? nil : cleanedFaultActor
        self.detail = detail
    }

    public init(
        faultCode: String,
        faultString: String,
        faultActor: String? = nil,
        detail: DetailPayload? = nil
    ) throws {
        let parsedFaultCode = try SOAPFaultCode(rawValue: faultCode)
        try self.init(
            faultCode: parsedFaultCode,
            faultString: faultString,
            faultActor: faultActor,
            detail: detail
        )
    }
    #endif
}

extension SOAPFault: Equatable where DetailPayload: Equatable {}
