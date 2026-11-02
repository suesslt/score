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

    func testRoundedAmountHalfUp() {
        XCTAssertEqual(Money(amount: Decimal(string: "1.005")!, currency: .chf).roundedAmount,
                       Decimal(string: "1.01")!)
        XCTAssertEqual(Money(amount: Decimal(string: "1.015")!, currency: .chf).roundedAmount,
                       Decimal(string: "1.02")!)
        XCTAssertEqual(Money(amount: Decimal(string: "-1.005")!, currency: .chf).roundedAmount,
                       Decimal(string: "-1.01")!)
        XCTAssertEqual(Money(amount: Decimal(string: "1.005")!, currency: .chf).rounded(.bankers).amount,
                       Decimal(string: "1.00")!)
        XCTAssertEqual(Money(amount: Decimal(string: "12.5")!, currency: .jpy).roundedAmount, 13)
    }

    /// Regression (bookscore): 4000 CHF incl. 8.1 % VAT split into net + vat summed to
    /// 4000.0000000000000000000000000000004449, so a 4000.00 payment counted as partial.
    func testEqualityAtCurrencyPrecision() {
        let raw = Decimal(4000) * Decimal(string: "8.1")! / Decimal(string: "108.1")!
        let gross = Money(amount: (Decimal(4000) - raw) + raw, currency: .chf)
        XCTAssertNotEqual(gross.amount, 4000)
        XCTAssertEqual(gross, Money.of(.chf, 4000))
        XCTAssertTrue(Money.of(.chf, 4000) >= gross)
        XCTAssertFalse(Money.of(.chf, 4000) < gross)
        XCTAssertEqual(Set([gross, Money.of(.chf, 4000)]).count, 1)
        XCTAssertNotEqual(Money.of(.chf, 4000), Money.of(.eur, 4000))
        XCTAssertNotEqual(Money(amount: Decimal(string: "0.01")!, currency: .chf), .zero(.chf))
        XCTAssertTrue(Money(amount: Decimal(string: "0.004")!, currency: .chf).isZero)
        XCTAssertFalse(Money(amount: Decimal(string: "0.004")!, currency: .chf).isPositive)
    }

    func testArithmeticStaysExact() {
        let third = Money.of(.chf, 1) / 3
        XCTAssertEqual((third * 3).amount, Decimal(string: "0.99999999999999999999999999999999999999")!)
        XCTAssertEqual(third * 3, Money.of(.chf, 1))
        XCTAssertEqual(third.rounded().amount, Decimal(string: "0.33")!)
    }

    func testVATSplitInclusiveIsExact() {
        let split = Money.of(.chf, 4000).vatSplit(ratePercent: Decimal(string: "8.1")!, inclusive: true)
        XCTAssertEqual(split.vat.amount, Decimal(string: "299.72")!)
        XCTAssertEqual(split.net.amount, Decimal(string: "3700.28")!)
        XCTAssertEqual((split.net + split.vat).amount, 4000)
        XCTAssertEqual(split.gross.amount, 4000)
    }

    func testVATSplitExclusive() {
        let split = Money.of(.chf, 4000).vatSplit(ratePercent: Decimal(string: "8.1")!, inclusive: false)
        XCTAssertEqual(split.net.amount, 4000)
        XCTAssertEqual(split.vat.amount, 324)
        XCTAssertEqual(split.gross.amount, 4324)
        let odd = Money(amount: Decimal(string: "33.33")!, currency: .chf)
            .vatSplit(ratePercent: Decimal(string: "2.6")!, inclusive: false)
        XCTAssertEqual(odd.vat.amount, Decimal(string: "0.87")!)   // 0.86658 → 0.87
        XCTAssertEqual(odd.gross.amount, Decimal(string: "34.20")!)
    }

    func testVATSplitZeroRate() {
        let split = Money.of(.chf, 100).vatSplit(ratePercent: 0, inclusive: true)
        XCTAssertEqual(split.net, Money.of(.chf, 100))
        XCTAssertTrue(split.vat.isZero)
    }

    func testSum() {
        XCTAssertEqual(Money.sum([Money.of(.chf, 1), Money.of(.chf, 2)], currency: .chf), Money.of(.chf, 3))
        XCTAssertEqual(Money.sum([], currency: .eur), .zero(.eur))
    }
}
