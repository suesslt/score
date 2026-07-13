import XCTest
@testable import Score

final class IbanNumberTests: XCTestCase {

    // MARK: - Init / normalization

    func testInitFailsForEmptyString() {
        XCTAssertNil(IbanNumber(""))
        XCTAssertNil(IbanNumber("   "))
    }

    func testInitNormalizesWhitespaceAndCase() {
        let iban = IbanNumber("ch93 0076 2011 6238 5295 7")
        XCTAssertEqual(iban?.normalized, "CH9300762011623852957")
    }

    // MARK: - Validation (delegated from value type)

    func testValidSwissIBAN() {
        XCTAssertTrue(IbanNumber("CH93 0076 2011 6238 5295 7")!.isValid)
    }

    func testValidGermanIBAN() {
        XCTAssertTrue(IbanNumber("DE89 3704 0044 0532 0130 00")!.isValid)
    }

    func testInvalidCheckDigit() {
        XCTAssertFalse(IbanNumber("CH93 0076 2011 6238 5295 0")!.isValid)
    }

    func testInvalidShort() {
        XCTAssertFalse(IbanNumber("CH93")!.isValid)
    }

    func testInvalidGarbage() {
        XCTAssertFalse(IbanNumber("foo")!.isValid)
    }

    func testInvalidNonAlphanumeric() {
        XCTAssertFalse(IbanNumber("CH93@@762011623852957")!.isValid)
    }

    // MARK: - QR-IBAN detection

    func testSwissQRIBAN() {
        // BC = 31999 ⇒ '3' an Position 5
        let iban = IbanNumber("CH44 3199 9123 0008 8901 2")!
        XCTAssertTrue(iban.isValid)
        XCTAssertTrue(iban.isQRIBAN)
        XCTAssertEqual(iban.kind, .qrIban)
    }

    func testRegularSwissIBANIsNotQRIBAN() {
        let iban = IbanNumber("CH93 0076 2011 6238 5295 7")!
        XCTAssertTrue(iban.isValid)
        XCTAssertFalse(iban.isQRIBAN)
        XCTAssertEqual(iban.kind, .regular)
    }

    func testGermanIBANIsNotQRIBAN() {
        let iban = IbanNumber("DE89 3704 0044 0532 0130 00")!
        XCTAssertTrue(iban.isValid)
        XCTAssertFalse(iban.isQRIBAN)
        XCTAssertEqual(iban.kind, .regular)
    }

    func testInvalidIBANClassifiesAsInvalid() {
        XCTAssertEqual(IbanNumber("foo")!.kind, .invalid)
    }

    // MARK: - Formatted display

    func testFormattedGroupsByFour() {
        let iban = IbanNumber("CH9300762011623852957")!
        XCTAssertEqual(iban.formatted, "CH93 0076 2011 6238 5295 7")
    }

    // MARK: - Static convenience

    func testStaticIsValid() {
        XCTAssertTrue(IbanNumber.isValid("CH93 0076 2011 6238 5295 7"))
        XCTAssertFalse(IbanNumber.isValid(""))
        XCTAssertFalse(IbanNumber.isValid("nope"))
    }

    func testStaticIsQRIBAN() {
        XCTAssertTrue(IbanNumber.isQRIBAN("CH44 3199 9123 0008 8901 2"))
        XCTAssertFalse(IbanNumber.isQRIBAN("CH93 0076 2011 6238 5295 7"))
        XCTAssertFalse(IbanNumber.isQRIBAN("invalid"))
    }
}
