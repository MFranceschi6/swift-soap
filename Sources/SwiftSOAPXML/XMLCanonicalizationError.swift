import Foundation
import SwiftSOAPCompatibility

public enum XMLCanonicalizationError: Error {
    case transformFailed(
        code: XMLCanonicalizationErrorCode,
        transformIndex: Int,
        transformType: String,
        underlyingError: SOAPAnyError?,
        message: String?
    )
    case serializationFailed(
        code: XMLCanonicalizationErrorCode,
        underlyingError: SOAPAnyError?,
        message: String?
    )
    case other(
        code: XMLCanonicalizationErrorCode,
        underlyingError: SOAPAnyError?,
        message: String?
    )
}
