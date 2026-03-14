import Foundation
import SwiftSOAPClientAsync

@main
struct CalculatorDemo {
    static func main() async throws {
        guard let endpoint = URL(string: "http://www.dneonline.com/calculator.asmx") else {
            throw URLError(.badURL)
        }
        let transport = URLSessionSOAPTransport()
        let soapClient = SOAPTransportClientAsync(
            transport: transport,
            wireCodec: .init(
                configuration: 
                .init(requestEncoder: .init(
                    configuration: .init(
                        writerConfiguration: .init(
                            prettyPrinted: true
                            )
                        )
                    )
                )
            )
        )
        let calculator = CalculatorCalculatorSoapAsyncClient(
            client: soapClient,
            endpointURL: endpoint
        )

        // Add: 10 + 5
        let addResponse = try await calculator.add(request: AddSoapInPayload(intA: 10, intB: 5))
        switch addResponse {
        case .success(let result):
            print("10 + 5 =", result.addResult ?? -1)
        case .fault(let fault):
            print("Add fault:", fault.faultString)
        }

        // Subtract: 10 - 5
        let subtractResponse = try await calculator.subtract(
            request: SubtractSoapInPayload(intA: 10, intB: 5)
        )
        switch subtractResponse {
        case .success(let result):
            print("10 - 5 =", result.subtractResult ?? -1)
        case .fault(let fault):
            print("Subtract fault:", fault.faultString)
        }

        // Multiply: 10 * 5
        let multiplyResponse = try await calculator.multiply(
            request: MultiplySoapInPayload(intA: 10, intB: 5)
        )
        switch multiplyResponse {
        case .success(let result):
            print("10 * 5 =", result.multiplyResult ?? -1)
        case .fault(let fault):
            print("Multiply fault:", fault.faultString)
        }

        // Divide: 10 / 5
        let divideResponse = try await calculator.divide(
            request: DivideSoapInPayload(intA: 10, intB: 0)
        )
        switch divideResponse {
        case .success(let result):
            print("10 / 5 =", result.divideResult ?? -1)
        case .fault(let fault):
            print("Divide fault:", fault.faultString)
        }
    }
}
