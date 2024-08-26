import Runner
import XCTest
import XCTestExtensions

final class ReleaseToolTests: XCTestCase {
  func testNoArguments() throws {
    let rt = Runner(for: productsDirectory.appendingPathComponent("rt"))
    let result = try! rt.sync(arguments: [])
    XCTAssertEqual(result.status, 0)
    XCTAssertTrue(result.stdout.contains("USAGE: command [--version] <subcommand>"))
  }
}
