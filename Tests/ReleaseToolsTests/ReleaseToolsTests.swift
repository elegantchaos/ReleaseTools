import XCTest
import XCTestExtensions
import Runner

final class ReleaseToolTests: XCTestCase {
    func testNoArguments() throws {
        let rt = Runner(for: productsDirectory.appendingPathComponent("rt"))
        let result = try! rt.sync(arguments: [])
        XCTAssertEqual(result.status, 2)
        XCTAssertTrue(result.stdout.contains("Usage:\n"))
    }
}
