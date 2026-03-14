import Foundation
import SwiftSOAPCore

struct URLSessionSOAPTransport: SOAPClientTransport {
    let session: URLSession = .shared

    func send(_ requestXMLData: Data, to endpointURL: URL, soapAction: String?) async throws -> Data {
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.httpBody = requestXMLData
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        if let action = soapAction {
            request.setValue(action, forHTTPHeaderField: "SOAPAction")
        }
        print("--- REQUEST ---\n\(String(bytes: requestXMLData, encoding: .utf8) ?? "<binary>")\n---")
        let (data, response) = try await session.data(for: request)
        _ = response
        print("--- RESPONSE ---\n\(String(bytes: data, encoding: .utf8) ?? "<binary>")\n---")
        return data
    }
}
