import XCTest
@testable import Score

final class SCORReferenceGeneratorTests: XCTestCase {

    func testFormatValid() {
        let result = SCORReferenceGenerator.format("000000042")
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.hasPrefix("RF"))
        XCTAssertTrue(result!.hasSuffix("000000042"))
    }

    func testEmptyInput() {
        XCTAssertNil(SCORReferenceGenerator.format(""))
        XCTAssertNil(SCORReferenceGenerator.format("   "))
    }

    func testNonNumeric() {
        XCTAssertNil(SCORReferenceGenerator.format("ABC123"))
    }
}
