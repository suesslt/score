import XCTest
@testable import Score

final class IBANValidatorTests: XCTestCase {

    func testValidSwissIBAN() {
        XCTAssertTrue(IBANValidator.isValid("CH93 0076 2011 6238 5295 7"))
    }

    func testValidGermanIBAN() {
        XCTAssertTrue(IBANValidator.isValid("DE89 3704 0044 0532 0130 00"))
    }

    func testValidGBIBAN() {
        XCTAssertTrue(IBANValidator.isValid("GB29 NWBK 6016 1331 9268 19"))
    }

    func testInvalidCheckDigit() {
        XCTAssertFalse(IBANValidator.isValid("CH93 0076 2011 6238 5295 0"))
    }

    func testTooShort() {
        XCTAssertFalse(IBANValidator.isValid("CH93"))
    }

    func testEmpty() {
        XCTAssertFalse(IBANValidator.isValid(""))
    }

    func testValidationMessageValid() {
        XCTAssertNil(IBANValidator.validationMessage("CH93 0076 2011 6238 5295 7"))
    }

    func testValidationMessageEmpty() {
        XCTAssertNil(IBANValidator.validationMessage(""))
    }

    func testValidationMessageInvalid() {
        XCTAssertNotNil(IBANValidator.validationMessage("INVALID"))
    }
}
