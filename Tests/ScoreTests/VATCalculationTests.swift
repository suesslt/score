import XCTest
@testable import Score

final class VATCalculationTests: XCTestCase {

    func testExclusive() {
        let result = VATCalculation.calculate(amount: 100, rate: Decimal(string: "8.1")!, inclusive: false)
        XCTAssertEqual(result.netAmount, 100)
        XCTAssertEqual(result.vatAmount, Decimal(string: "8.1")!)
    }

    func testInclusive() {
        let result = VATCalculation.calculate(amount: Decimal(string: "108.10")!, rate: Decimal(string: "8.1")!, inclusive: true)
        XCTAssertEqual(result.netAmount, 100)
        XCTAssertEqual(result.vatAmount, Decimal(string: "8.10")!)
    }
}
