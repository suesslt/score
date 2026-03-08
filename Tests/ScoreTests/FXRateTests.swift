import XCTest
@testable import Score

final class FXRateTests: XCTestCase {

    func testMidRate() {
        let rate = FXRate(baseCurrency: .eur, quoteCurrency: .usd, bid: Decimal(string: "1.08")!, ask: Decimal(string: "1.10")!)
        XCTAssertEqual(rate.mid, Decimal(string: "1.09")!)
    }

    func testSpread() {
        let rate = FXRate(baseCurrency: .eur, quoteCurrency: .usd, bid: Decimal(string: "1.08")!, ask: Decimal(string: "1.10")!)
        XCTAssertEqual(rate.spread, Decimal(string: "0.02")!)
    }

    func testSingleRate() {
        let rate = FXRate(baseCurrency: .eur, quoteCurrency: .chf, rate: Decimal(string: "0.95")!)
        XCTAssertEqual(rate.bid, rate.ask)
        XCTAssertEqual(rate.mid, Decimal(string: "0.95")!)
        XCTAssertEqual(rate.spread, 0)
    }

    func testIdentity() {
        let rate = FXRate.identity(.chf)
        XCTAssertEqual(rate.baseCurrency, .chf)
        XCTAssertEqual(rate.quoteCurrency, .chf)
        XCTAssertEqual(rate.mid, 1)
    }

    func testConvertMid() {
        let rate = FXRate(baseCurrency: .eur, quoteCurrency: .usd, rate: Decimal(2))
        let eur = Money(amount: 100, currency: .eur)
        let usd = rate.convert(eur)
        XCTAssertEqual(usd.amount, 200)
        XCTAssertEqual(usd.currency, .usd)
    }

    func testConvertInverse() {
        let rate = FXRate(baseCurrency: .eur, quoteCurrency: .usd, rate: Decimal(2))
        let usd = Money(amount: 200, currency: .usd)
        let eur = rate.convertInverse(usd)
        XCTAssertEqual(eur.amount, 100)
        XCTAssertEqual(eur.currency, .eur)
    }

    func testInverted() {
        let rate = FXRate(baseCurrency: .eur, quoteCurrency: .usd, rate: Decimal(2))
        let inv = rate.inverted
        XCTAssertEqual(inv.baseCurrency, .usd)
        XCTAssertEqual(inv.quoteCurrency, .eur)
        XCTAssertEqual(inv.mid, Decimal(string: "0.5")!)
    }

    func testCodable() throws {
        let original = FXRate(baseCurrency: .eur, quoteCurrency: .chf, bid: Decimal(string: "0.94")!, ask: Decimal(string: "0.96")!)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FXRate.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
