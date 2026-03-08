import XCTest
@testable import Score

final class PercentTests: XCTestCase {

    func testParseString() {
        let p = Percent.of("10%")
        XCTAssertEqual(p.factorAmount, Decimal(string: "0.1")!)
    }

    func testParseFactor() {
        let p = Percent.of(Decimal(string: "0.25")!)
        XCTAssertEqual(p.factorAmount, Decimal(string: "0.25")!)
    }

    func testDisplayValue() {
        let p = Percent.of("10%")
        XCTAssertEqual(p.displayValue, 10)
    }

    func testDescription() {
        let p = Percent.of("10%")
        XCTAssertEqual(p.description, "10%")
    }

    func testAdd() {
        let a = Percent.of("10%")
        let b = Percent.of("5%")
        let result = a.add(b)
        XCTAssertEqual(result.factorAmount, Decimal(string: "0.15")!)
    }

    func testSubtract() {
        let a = Percent.of("10%")
        let b = Percent.of("3%")
        let result = a.subtract(b)
        XCTAssertEqual(result.factorAmount, Decimal(string: "0.07")!)
    }

    func testNegate() {
        let p = Percent.of("10%")
        XCTAssertEqual(p.negate().factorAmount, Decimal(string: "-0.1")!)
    }

    func testComparable() {
        let a = Percent.of("10%")
        let b = Percent.of("20%")
        XCTAssertTrue(a < b)
    }

    func testApplyTo() {
        let p = Percent.of("50%")
        XCTAssertEqual(p.applyTo(200), 100)
    }

    func testDiscount() {
        let p = Percent.of("20%")
        XCTAssertEqual(p.discount(100), 80)
    }

    func testCodable() throws {
        let original = Percent.of("15%")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Percent.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
