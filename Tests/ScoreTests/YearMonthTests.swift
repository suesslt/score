import XCTest
@testable import Score

final class YearMonthTests: XCTestCase {

    func testFactory() {
        let ym = YearMonth.of(2026, 3)
        XCTAssertEqual(ym.year, 2026)
        XCTAssertEqual(ym.month, 3)
    }

    func testParse() {
        let ym = YearMonth.parse("2026-03")
        XCTAssertEqual(ym.year, 2026)
        XCTAssertEqual(ym.month, 3)
    }

    func testPlusMonths() {
        let ym = YearMonth.of(2026, 11)
        let result = ym.plusMonths(3)
        XCTAssertEqual(result.year, 2027)
        XCTAssertEqual(result.month, 2)
    }

    func testPlusMonthsNegative() {
        let ym = YearMonth.of(2026, 3)
        let result = ym.plusMonths(-4)
        XCTAssertEqual(result.year, 2025)
        XCTAssertEqual(result.month, 11)
    }

    func testLengthOfMonth() {
        XCTAssertEqual(YearMonth.of(2026, 2).lengthOfMonth, 28)
        XCTAssertEqual(YearMonth.of(2024, 2).lengthOfMonth, 29) // leap year
        XCTAssertEqual(YearMonth.of(2026, 1).lengthOfMonth, 31)
    }

    func testComparable() {
        let a = YearMonth.of(2026, 1)
        let b = YearMonth.of(2026, 12)
        XCTAssertTrue(a < b)
        XCTAssertTrue(a.isBefore(b))
        XCTAssertTrue(b.isAfter(a))
    }

    func testMonthDiff() {
        let start = YearMonth.of(2025, 6)
        let end = YearMonth.of(2026, 3)
        XCTAssertEqual(YearMonth.monthDiff(end: end, start: start), 9)
    }

    func testDescription() {
        XCTAssertEqual(YearMonth.of(2026, 3).description, "2026-03")
        XCTAssertEqual(YearMonth.of(2026, 12).description, "2026-12")
    }

    func testCodable() throws {
        let original = YearMonth.of(2026, 3)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(YearMonth.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
