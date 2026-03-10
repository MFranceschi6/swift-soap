# SwiftSOAP

A type-safe SOAP 1.1/1.2 client and server library for Swift, backed by libxml2.

[![CI](https://github.com/MFranceschi6/swift-soap/actions/workflows/ci.yml/badge.svg)](https://github.com/MFranceschi6/swift-soap/actions)
[![Swift 5.4+](https://img.shields.io/badge/Swift-5.4%2B-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-lightgrey.svg)](https://swift.org)
[![SPM](https://img.shields.io/badge/spm-compatible-brightgreen.svg)](https://swift.org/package-manager)

## Features

- **Type-safe SOAP operations** — define request, response, and fault types with `Codable`
- **Precise XML codec** powered by libxml2 with full namespace and CDATA support
- **Macro-driven field mapping** — annotate properties with `@XMLAttribute` / `@XMLElement` (Swift 5.9+)
- **Transport-agnostic** — plug in any HTTP library via the `SOAPClientTransport` protocol
- **WSDL 1.1 parser and code generator** for automated stub generation
- **async/await** and **NIO** client bindings included
- **Linux-compatible** — no Apple-only APIs in the runtime path

---

## Installation

Add SwiftSOAP to your `Package.swift`:

```swift
.package(url: "https://github.com/MFranceschi6/swift-soap.git", from: "1.0.0")
```

Then add the products you need to your target's dependencies:

| Use case | Product |
|----------|---------|
| SOAP envelopes, wire codec, transport protocols | `SwiftSOAPCore` |
| XML encoding / decoding (`Codable`-compatible) | `SwiftSOAPXML` |
| `@XMLCodable`, `@XMLAttribute`, `@XMLElement` macros (Swift 5.9+) | `SwiftSOAPXMLMacros` |
| async/await SOAP client | `SwiftSOAPClientAsync` |
| NIO-based SOAP client | `SwiftSOAPClientNIO` |
| async server integration | `SwiftSOAPServerAsync` |
| NIO server integration | `SwiftSOAPServerNIO` |
| WSDL 1.1 parser | `SwiftSOAPWSDL` |
| SPM build-tool code generation (Swift 6.1) | `SwiftSOAPCodeGenPlugin` |

---

## Quick Start

The following example calls a fictional weather SOAP service.

### 1. Define the operation

```swift
import SwiftSOAPCore
import SwiftSOAPXMLMacros  // @XMLCodable, @XMLAttribute, @XMLElement — Swift 5.9+

// Request payload
@XMLCodable
struct GetWeatherRequest: SOAPBodyPayload {
    @XMLElement var city: String
    @XMLElement var countryCode: String
}

// Response payload
@XMLCodable
struct GetWeatherResponse: SOAPBodyPayload {
    @XMLElement var temperatureCelsius: Double
    @XMLElement var description: String
}

// Operation contract: wires together the request, response, and fault types
struct GetWeatherOperation: SOAPOperationContract {
    typealias RequestPayload     = GetWeatherRequest
    typealias ResponsePayload    = GetWeatherResponse
    typealias FaultDetailPayload = SOAPEmptyFaultDetailPayload

    static let operationIdentifier = SOAPOperationIdentifier(rawValue: "GetWeather")
    static let soapAction          = SOAPAction(rawValue: "http://example.com/weather/GetWeather")
}
```

### 2. Provide a transport

A transport bridges SwiftSOAP to an HTTP library via a single async method.
Until `swift-soap-urlsession-transport` is released as a standalone package,
implement one directly:

```swift
import Foundation
import SwiftSOAPCore

struct URLSessionSOAPTransport: SOAPClientTransport {
    let session: URLSession = .shared

    func send(_ requestXMLData: Data, to endpointURL: URL, soapAction: String?) async throws -> Data {
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        if let soapAction {
            request.setValue(soapAction, forHTTPHeaderField: "SOAPAction")
        }
        request.httpBody = requestXMLData
        let (data, _) = try await session.data(for: request)
        return data
    }
}
```

### 3. Invoke the operation

```swift
import SwiftSOAPClientAsync

let client   = SOAPTransportClientAsync(transport: URLSessionSOAPTransport())
let endpoint = URL(string: "https://example.com/WeatherService")!

let response = try await client.invoke(
    GetWeatherOperation.self,
    request: GetWeatherRequest(city: "London", countryCode: "GB"),
    endpointURL: endpoint
)

switch response {
case .success(let body):
    print("Temperature: \(body.temperatureCelsius) °C — \(body.description)")
case .fault(let fault, _):
    print("SOAP fault [\(fault.faultCode ?? "?")]: \(fault.faultString ?? "unknown")")
}
```

---

## Modules

| Module | Role | When to import |
|--------|------|----------------|
| `SwiftSOAPCore` | Core types: envelopes, faults, wire codec, transport protocols | Always |
| `SwiftSOAPXML` | Low-level XML codec: `XMLEncoder`, `XMLDecoder`, `XMLTreeParser`, `XMLTreeWriter` | Direct XML manipulation |
| `SwiftSOAPXMLMacros` | Compile-time macros: `@XMLCodable`, `@XMLAttribute`, `@XMLElement` | Swift 5.9+; XML field mapping |
| `SwiftSOAPWSDL` | WSDL 1.1 document parser (`WSDLDocumentParser`) | Parsing WSDL at runtime |
| `SwiftSOAPClientAsync` | `SOAPTransportClientAsync` — async/await SOAP client | Calling SOAP services |
| `SwiftSOAPClientNIO` | NIO-based async SOAP client | Server-side / NIO applications |
| `SwiftSOAPServerAsync` | `SOAPServerAsync` integration protocol | Building SOAP servers (async) |
| `SwiftSOAPServerNIO` | `SOAPServerNIO` integration protocol | Building SOAP servers (NIO) |

---

## Architecture

```
libxml2 (system)
    │
    ├─ SwiftSOAPXMLCShim ─── SwiftSOAPCompatibility ─── SwiftSOAPXMLOwnership6
    │
    └─ SwiftSOAPXML          (XML codec, tree layer — zero SOAP coupling)
           │
           ├─ SwiftSOAPCore  (envelopes, wire codec, transport protocols)
           │       │
           │       ├─ SwiftSOAPClientAsync  ◄── your transport
           │       ├─ SwiftSOAPClientNIO    ◄── your transport
           │       ├─ SwiftSOAPServerAsync  ◄── your web framework adapter
           │       └─ SwiftSOAPServerNIO    ◄── your web framework adapter
           │
           ├─ SwiftSOAPWSDL  (WSDL 1.1 parser)
           │       └─ SwiftSOAPCodeGenCore  (IR builder + Swift source emitter)
           │               └─ SwiftSOAPCodeGen  (CLI + SPM build plugin)
           │
           └─ SwiftSOAPXMLMacros            (macro re-exports, Swift 5.9+)
                   └─ SwiftSOAPXMLMacroImplementation  (compiler plugin)
```

### Transport plugin model

`SOAPClientTransport` is a one-method protocol. Concrete HTTP implementations live
in separate packages — matching the pattern used by
[`swift-openapi-runtime`](https://github.com/apple/swift-openapi-runtime):

| Package | Transport |
|---------|-----------|
| `swift-soap` _(this repo)_ | Protocol definition only |
| `swift-soap-urlsession-transport` _(coming soon)_ | URLSession (Foundation) |
| `swift-soap-async-http-client-transport` _(post-v1.0)_ | AsyncHTTPClient / NIO |

Implementing a custom transport requires a single method:

```swift
public protocol SOAPClientTransport: Sendable {
    func send(
        _ requestXMLData: Data,
        to endpointURL: URL,
        soapAction: String?
    ) async throws -> Data
}
```

That is everything the library needs from an HTTP layer. Headers, TLS, authentication,
and redirect handling are entirely the responsibility of the transport implementation.

---

## XML Field Mapping

### With macros (Swift 5.9+)

```swift
import SwiftSOAPXMLMacros

@XMLCodable
struct Invoice: SOAPBodyPayload {
    @XMLAttribute var invoiceVersion: String  // → <Invoice invoiceVersion="…">
    @XMLElement   var invoiceNumber: Int      // → <invoiceNumber>…</invoiceNumber>
    var currency: String                      // → element (encoder default)
}
```

`@XMLCodable` synthesises a static lookup table that `XMLEncoder` and `XMLDecoder`
consult to decide which fields are serialised as XML attributes and which as child
elements. Properties without an annotation default to elements.

> **Naming note:** `@XMLElement` can conflict with `Foundation.XMLElement` (available
> on Apple platforms) when both `Foundation` and `SwiftSOAPXMLMacros` are in the same
> file. Disambiguate with the fully-qualified form `@SwiftSOAPXMLMacros.XMLElement`.

### With property wrappers (Swift 5.4+)

For targets below Swift 5.9, use the `XMLAttribute<T>` and `XMLElement<T>` property
wrappers from `SwiftSOAPXML`:

```swift
import SwiftSOAPXML

struct Invoice: SOAPBodyPayload {
    @XMLAttribute var invoiceVersion: String
    @XMLElement   var invoiceNumber: Int
    var currency: String
}
```

Property wrappers and macros can coexist in the same project on different types.

---

## WSDL Code Generation

### SPM build plugin (Swift 6.1)

Add `SwiftSOAPCodeGenPlugin` as a build tool plugin to your target and provide a
`swift-soap-codegen.json` configuration file alongside your source files. The plugin runs
automatically during `swift build`.

> **Note:** The plugin currently processes one WSDL file per target (one
> `swift-soap-codegen.json` per target directory). Multi-WSDL support is planned.

### CLI

```bash
swift run SwiftSOAPCodeGen --config path/to/soap-codegen.json
```

**Minimal `soap-codegen.json`:**

```json
{
  "wsdlPath": "path/to/service.wsdl",
  "moduleName": "MyServiceClient",
  "targetSwiftVersion": "6.0",
  "outputMode": "export",
  "exportOutputDirectory": "Sources/Generated",
  "runtimeTargets": ["async"],
  "generationScope": ["client"]
}
```

Key options:

| Flag | JSON key | Description |
|------|----------|-------------|
| `--config <path>` | — | Path to the JSON configuration file |
| `--wsdl <path>` | `wsdlPath` | WSDL source path |
| `--module-name <name>` | `moduleName` | Generated module name |
| `--target-swift <major.minor>` | `targetSwiftVersion` | Target Swift version, e.g. `"6.0"` |
| `--runtime-targets <async,nio>` | `runtimeTargets` | `["async"]`, `["nio"]`, or both |
| `--generation-scope <client,server>` | `generationScope` | `["client"]`, `["server"]`, or both |
| `--output-mode <build\|export\|both>` | `outputMode` | Output destination |

---

## Server Integration

`SOAPServerAsync` and `SOAPServerNIO` are integration-point protocols. The library
does not bundle concrete web framework adapters — you implement a thin wrapper around
your framework of choice.

Example Vapor stub:

```swift
import Vapor
import SwiftSOAPCore
import SwiftSOAPServerAsync

final class VaporSOAPServer: SOAPServerAsync {
    let app: Application

    func register<Op: SOAPOperationContract>(
        _ operation: Op.Type,
        handler: @escaping SOAPAsyncOperationHandler<Op>
    ) {
        app.post(.constant(Op.operationIdentifier.rawValue)) { req async throws -> Response in
            let requestData = Data(buffer: req.body.data ?? .init())
            // Decode envelope, dispatch to handler, encode response envelope
            _ = try await handler(requestData)
            return Response(status: .ok)
        }
    }

    func start() async throws { try await app.startup() }
    func stop()  async throws { try await app.asyncShutdown() }
}
```

---

## Contributing

Contributions, issues, and pull requests are welcome.

```bash
# Build
swift build -c debug

# Test
swift test --enable-code-coverage

# Lint
swiftlint lint

# Cross-version CI matrix
./scripts/ci-local-matrix.sh
```

---

_SwiftSOAP requires macOS 10.15+ or Linux. The library is pre-1.0; API stability is
not guaranteed until the v1.0.0 tag._
