import XCTest
@testable import Score

final class MoneyTests: XCTestCase {

    func testAdditionSameCurrency() {
        let a = Money(amount: 100, currency: .chf)
        let b = Money(amount: 50, currency: .chf)
        let result = a + b
        XCTAssertEqual(result.amount, 150)
        XCTAssertEqual(result.currency, .chf)
    }

    func testSubtractionSameCurrency() {
        let a = Money(amount: 100, currency: .eur)
        let b = Money(amount: 30, currency: .eur)
        let result = a - b
        XCTAssertEqual(result.amount, 70)
    }

    func testMultiplication() {
        let m = Money(amount: 100, currency: .usd)
        let result = m * Decimal(0.1)
        XCTAssertEqual(result.amount, 10)
        XCTAssertEqual(result.currency, .usd)
    }

    func testDivision() {
        let m = Money(amount: 100, currency: .chf)
        let result = m / Decimal(4)
        XCTAssertEqual(result.amount, 25)
    }

    func testNegation() {
        let m = Money(amount: 50, currency: .chf)
        let neg = -m
        XCTAssertEqual(neg.amount, -50)
        XCTAssertEqual(neg.currency, .chf)
    }

    func testZeroFactory() {
        let z = Money.zero(.eur)
        XCTAssertEqual(z.amount, .zero)
        XCTAssertEqual(z.currency, .eur)
        XCTAssertTrue(z.isZero)
    }

    func testPositiveNegative() {
        let pos = Money(amount: 10, currency: .chf)
        let neg = Money(amount: -10, currency: .chf)
        XCTAssertTrue(pos.isPositive)
        XCTAssertFalse(pos.isNegative)
        XCTAssertTrue(neg.isNegative)
        XCTAssertFalse(neg.isPositive)
    }

    func testComparable() {
        let a = Money(amount: 50, currency: .chf)
        let b = Money(amount: 100, currency: .chf)
        XCTAssertTrue(a < b)
        XCTAssertTrue(b > a)
        XCTAssertTrue(a <= b)
        XCTAssertTrue(b >= a)
    }

    func testThrowingAddMismatch() throws {
        let chf = Money(amount: 100, currency: .chf)
        let eur = Money(amount: 50, currency: .eur)
        XCTAssertThrowsError(try chf.adding(eur))
    }

    func testThrowingAddSame() throws {
        let a = Money(amount: 100, currency: .chf)
        let b = Money(amount: 50, currency: .chf)
        let result = try a.adding(b)
        XCTAssertEqual(result.amount, 150)
    }

    func testSwiss5RappenRounding() {
        let m1 = Money(amount: Decimal(string: "10.12")!, currency: .chf)
        let r1 = m1.roundedTo5Centimes()
        XCTAssertEqual(r1.amount, Decimal(string: "10.10")!)

        let m2 = Money(amount: Decimal(string: "10.13")!, currency: .chf)
        let r2 = m2.roundedTo5Centimes()
        XCTAssertEqual(r2.amount, Decimal(string: "10.15")!)

        let m3 = Money(amount: Decimal(string: "10.17")!, currency: .chf)
        let r3 = m3.roundedTo5Centimes()
        XCTAssertEqual(r3.amount, Decimal(string: "10.15")!)
    }

    func testNullSafeAdd() {
        let a = Money(amount: 100, currency: .chf)
        XCTAssertEqual(Money.add(a, nil)?.amount, 100)
        XCTAssertEqual(Money.add(nil, a)?.amount, 100)
        XCTAssertNil(Money.add(nil, nil))
    }

    func testCodable() throws {
        let original = Money(amount: Decimal(string: "123.45")!, currency: .chf)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Money.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testAbsoluteValue() {
        let neg = Money(amount: -42, currency: .usd)
        XCTAssertEqual(neg.absoluteValue.amount, 42)
    }

    // MARK: - Factories

    func testOfFactories() {
        XCTAssertEqual(Money.of(.chf, Decimal(string: "1234.56")!),
                       Money(amount: Decimal(string: "1234.56")!, currency: .chf))
        XCTAssertEqual(Money.of(.eur, 100), Money(amount: 100, currency: .eur))
        XCTAssertEqual(Money.of(.usd, 99.5).amount, Decimal(99.5))
        XCTAssertEqual(Money.of(code: "chf", 10), Money(amount: 10, currency: .chf))
        XCTAssertNil(Money.of(code: "XXX_UNKNOWN", 10))
    }

    // MARK: - Parsing

    func testParsePrefixAndSuffix() {
        XCTAssertEqual(Money.parse("CHF 1234.56"),
                       Money(amount: Decimal(string: "1234.56")!, currency: .chf))
        XCTAssertEqual(Money.parse("1234.56 CHF"),
                       Money(amount: Decimal(string: "1234.56")!, currency: .chf))
        XCTAssertEqual(Money.parse("  eur 50 "), Money(amount: 50, currency: .eur))
        XCTAssertNil(Money.parse("CHF"))
        XCTAssertNil(Money.parse("1234.56"))
        XCTAssertNil(Money.parse("ZZZ 100"))
        XCTAssertNil(Money.parse(""))
    }

    // MARK: - Formatting

    func testFormattedSwiss() {
        let m = Money(amount: Decimal(string: "1234.56")!, currency: .chf)
        // de_CH groups with apostrophe (ICU uses U+2019); normalize for a stable assertion.
        let normalized = m.formatted.replacingOccurrences(of: "\u{2019}", with: "'")
        XCTAssertEqual(normalized, "1'234.56 CHF")
    }

    func testDescriptionIsLocaleIndependent() {
        XCTAssertEqual(Money(amount: Decimal(string: "1234.5")!, currency: .chf).description,
                       "CHF 1234.50")
        XCTAssertEqual(Money(amount: 7, currency: .jpy).description, "JPY 7")
        XCTAssertEqual(Money(amount: Decimal(string: "-1.25")!, currency: .chf).description,
                       "CHF -1.25")
    }

    func testRoundedAmountBankers() {
        XCTAssertEqual(Money(amount: Decimal(string: "1.005")!, currency: .chf).roundedAmount,
                       Decimal(string: "1.00")!)
        XCTAssertEqual(Money(amount: Decimal(string: "1.015")!, currency: .chf).roundedAmount,
                       Decimal(string: "1.02")!)
    }
}
