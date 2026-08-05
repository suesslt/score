import XCTest
@testable import Score

final class PostalAddressTests: XCTestCase {

    // MARK: - isPopulated

    func testEmptyAddressIsNotPopulated() {
        XCTAssertFalse(PostalAddress().isPopulated)
    }

    func testStreetMakesAddressPopulated() {
        XCTAssertTrue(PostalAddress(street: "Musterstrasse").isPopulated)
    }

    func testPoBoxMakesAddressPopulated() {
        XCTAssertTrue(PostalAddress(poBox: "Postfach 12").isPopulated)
    }

    // MARK: - Formatting

    func testSummaryJoinsSetFields() {
        let address = PostalAddress(street: "Musterstrasse", houseNumber: "1",
                                    postalCode: "8000", city: "Zürich")
        XCTAssertEqual(address.summary, "Musterstrasse 1 8000 Zürich")
    }

    func testSummarySkipsEmptyFields() {
        let address = PostalAddress(street: "Musterstrasse", postalCode: "8000")
        XCTAssertEqual(address.summary, "Musterstrasse 8000")
    }

    func testFormattedMultiline() {
        let address = PostalAddress(attention: "z.Hd. Frau Muster", street: "Musterstrasse",
                                    houseNumber: "1", addressLine1: "Haus A",
                                    poBox: "Postfach 12", postalCode: "8000", city: "Zürich")
        XCTAssertEqual(address.formatted,
                       "z.Hd. Frau Muster\nHaus A\nMusterstrasse 1\nPostfach 12\n8000 Zürich")
    }

    func testFormattedWithNamePrependsName() {
        let address = PostalAddress(street: "Musterstrasse", houseNumber: "1",
                                    postalCode: "8000", city: "Zürich")
        XCTAssertEqual(address.formatted(withName: "Muster AG"),
                       "Muster AG\nMusterstrasse 1\n8000 Zürich")
    }

    func testFormattedWithNameOnEmptyAddressIsJustTheName() {
        XCTAssertEqual(PostalAddress().formatted(withName: "Muster AG"), "Muster AG")
    }

    // MARK: - normalized()

    func testNormalizedTrimsAllFieldsAndUppercasesCountry() {
        let address = PostalAddress(attention: " z.Hd. ", street: " Musterstrasse ",
                                    houseNumber: " 1 ", addressLine1: " a ",
                                    addressLine2: " b ", poBox: " Postfach ",
                                    postalCode: " 8000 ", city: " Zürich ",
                                    countryCode: " ch ")
        let n = address.normalized()
        XCTAssertEqual(n.attention, "z.Hd.")
        XCTAssertEqual(n.street, "Musterstrasse")
        XCTAssertEqual(n.houseNumber, "1")
        XCTAssertEqual(n.addressLine1, "a")
        XCTAssertEqual(n.addressLine2, "b")
        XCTAssertEqual(n.poBox, "Postfach")
        XCTAssertEqual(n.postalCode, "8000")
        XCTAssertEqual(n.city, "Zürich")
        XCTAssertEqual(n.countryCode, "CH")
    }

    // MARK: - validationIssues

    func testEmptyAddressIsValid() {
        XCTAssertTrue(PostalAddress().validationIssues.isEmpty)
    }

    func testCompletePopulatedAddressIsValid() {
        let address = PostalAddress(street: "Musterstrasse", houseNumber: "1",
                                    postalCode: "8000", city: "Zürich")
        XCTAssertTrue(address.validationIssues.isEmpty)
    }

    func testPopulatedAddressWithoutPostalCodeReportsIssue() {
        let address = PostalAddress(street: "Musterstrasse", city: "Zürich")
        XCTAssertEqual(address.validationIssues, [.missingPostalCode])
    }

    func testPopulatedAddressWithoutCityReportsIssue() {
        let address = PostalAddress(street: "Musterstrasse", postalCode: "8000")
        XCTAssertEqual(address.validationIssues, [.missingCity])
    }

    func testPopulatedAddressWithoutPlaceReportsBothIssues() {
        let address = PostalAddress(poBox: "Postfach 12")
        XCTAssertEqual(address.validationIssues, [.missingPostalCode, .missingCity])
    }

    func testWhitespaceOnlyPlaceCountsAsMissing() {
        // Validation runs over the normalized form — blanks must not pass.
        let address = PostalAddress(street: "Musterstrasse", postalCode: "  ", city: " ")
        XCTAssertEqual(address.validationIssues, [.missingPostalCode, .missingCity])
    }

    func testInvalidCountryCodeReportsIssue() {
        XCTAssertEqual(PostalAddress(countryCode: "CHE").validationIssues, [.invalidCountryCode])
        XCTAssertEqual(PostalAddress(countryCode: "C1").validationIssues, [.invalidCountryCode])
    }

    func testLowercaseCountryCodeIsValidAfterNormalization() {
        XCTAssertTrue(PostalAddress(countryCode: "ch").validationIssues.isEmpty)
    }

    func testEmptyCountryCodeIsValid() {
        XCTAssertTrue(PostalAddress(countryCode: "").validationIssues.isEmpty)
    }

    func testIssueFieldNamesMatchProperties() {
        XCTAssertEqual(PostalAddressIssue.missingPostalCode.field, "postalCode")
        XCTAssertEqual(PostalAddressIssue.missingCity.field, "city")
        XCTAssertEqual(PostalAddressIssue.invalidCountryCode.field, "countryCode")
    }

    // MARK: - Codable

    func testCodableRoundtrip() throws {
        let address = PostalAddress(attention: "z.Hd.", street: "Musterstrasse",
                                    houseNumber: "1", addressLine1: "a", addressLine2: "b",
                                    poBox: "Postfach", postalCode: "8000", city: "Zürich",
                                    countryCode: "CH")
        let data = try JSONEncoder().encode(address)
        let decoded = try JSONDecoder().decode(PostalAddress.self, from: data)
        XCTAssertEqual(decoded, address)
    }

    // MARK: - AddressScheme

    func testAddressSchemeRawValuesAreStable() {
        // The raw values are a persistence contract in the consuming projects
        // (CloudKit/SQLite/Postgres store them as TEXT) — never rename.
        XCTAssertEqual(AddressScheme.correspondence.rawValue, "correspondence")
        XCTAssertEqual(AddressScheme.domicile.rawValue, "domicile")
        XCTAssertEqual(AddressScheme.invoice.rawValue, "invoice")
        XCTAssertEqual(AddressScheme.allCases.count, 3)
    }
}
