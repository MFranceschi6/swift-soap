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
        do {
            let result = try await calculator.add(request: AddSoapInPayload(intA: 10, intB: 5))
            print("10 + 5 =", result.addResult ?? -1)
        } catch {
            print("Add error:", error)
        }

        // Subtract: 10 - 5
        do {
            let result = try await calculator.subtract(request: SubtractSoapInPayload(intA: 10, intB: 5))
            print("10 - 5 =", result.subtractResult ?? -1)
        } catch {
            print("Subtract error:", error)
        }

        // Multiply: 10 * 5
        do {
            let result = try await calculator.multiply(request: MultiplySoapInPayload(intA: 10, intB: 5))
            print("10 * 5 =", result.multiplyResult ?? -1)
        } catch {
            print("Multiply error:", error)
        }

        // Divide: 10 / 5
        do {
            let result = try await calculator.divide(request: DivideSoapInPayload(intA: 10, intB: 5))
            print("10 / 5 =", result.divideResult ?? -1)
        } catch {
            print("Divide error:", error)
        }
    }
}
