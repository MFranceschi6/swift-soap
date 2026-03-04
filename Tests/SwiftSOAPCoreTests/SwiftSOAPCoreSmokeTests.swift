import SwiftSOAPCore
import XCTest

final class SwiftSOAPCoreSmokeTests: XCTestCase {
    func test_module_is_loadable() {
        _ = SwiftSOAPCoreModule.self
    }
}
