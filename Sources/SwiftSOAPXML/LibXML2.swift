import CLibXML2
import Foundation

enum LibXML2 {
    static let initializeOnce: Void = {
        xmlInitParser()
    }()

    static func ensureInitialized() {
        _ = initializeOnce
    }

    static func withXMLCharPointer<Result>(
        _ string: String,
        _ body: (UnsafePointer<xmlChar>?) throws -> Result
    ) rethrows -> Result {
        var bytes = Array(string.utf8)
        bytes.append(0)
        return try bytes.withUnsafeBufferPointer { buffer in
            try body(buffer.baseAddress)
        }
    }
}
