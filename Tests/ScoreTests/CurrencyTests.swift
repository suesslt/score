import XCTest
@testable import Score

final class CurrencyTests: XCTestCase {

    func testDecimalPlaces() {
        XCTAssertEqual(Currency.chf.decimalPlaces, 2)
        XCTAssertEqual(Currency.usd.decimalPlaces, 2)
        XCTAssertEqual(Currency.jpy.decimalPlaces, 0)
        XCTAssertEqual(Currency.bhd.decimalPlaces, 3)
        XCTAssertEqual(Currency.mga.decimalPlaces, 1)
    }

    func testSymbols() {
        XCTAssertEqual(Currency.chf.symbol, "Fr.")
        XCTAssertEqual(Currency.usd.symbol, "$")
        XCTAssertEqual(Currency.eur.symbol, "\u{20AC}")
        XCTAssertEqual(Currency.gbp.symbol, "\u{00A3}")
    }

    func testNames() {
        XCTAssertEqual(Currency.chf.name, "Swiss Franc")
        XCTAssertEqual(Currency.usd.name, "US Dollar")
        XCTAssertEqual(Currency.eur.name, "Euro")
    }

    func testIdentifiable() {
        XCTAssertEqual(Currency.chf.id, "CHF")
    }

    func testCommonCurrencies() {
        XCTAssertTrue(Currency.common.contains(.chf))
        XCTAssertTrue(Currency.common.contains(.usd))
        XCTAssertTrue(Currency.common.contains(.eur))
    }

    func testCodable() throws {
        let original = Currency.chf
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Currency.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
