import Foundation
import SwiftSOAPCompatibility
import SwiftSOAPXMLCShim
#if swift(>=6.0)
import SwiftSOAPXMLOwnership6
#endif

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

    static func withOwnedXMLCharPointer<Result>(
        _ pointer: UnsafeMutablePointer<xmlChar>?,
        _ body: (UnsafeMutablePointer<xmlChar>) throws -> Result
    ) rethrows -> Result? {
        #if swift(>=6.0)
        return try SwiftSOAPXMLOwnership6.withOwnedXMLCharPointer(pointer, body)
        #else
        guard let pointer = pointer else {
            return nil
        }

        defer {
            swiftsoap_xml_free_xml_char(pointer)
        }
        return try body(pointer)
        #endif
    }
}
