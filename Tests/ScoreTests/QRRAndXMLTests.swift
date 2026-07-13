import XCTest
@testable import Score

final class QRRReferenceGeneratorTests: XCTestCase {

    func testCheckDigitKnownValue() {
        // Referenzbeispiel aus der SIX-Spezifikation: 21 00000 00003 13947 14300 09017
        XCTAssertEqual(QRRReferenceGenerator.checkDigit("21000000000313947143000901"), 7)
        XCTAssertTrue(QRRReferenceGenerator.isValid("210000000003139471430009017"))
    }

    func testGenerateProducesValidReference() {
        for _ in 0..<25 {
            let reference = QRRReferenceGenerator.generate()
            XCTAssertEqual(reference.count, 27)
            XCTAssertTrue(QRRReferenceGenerator.isValid(reference))
        }
    }

    func testIsValidRejectsWrongCheckDigit() {
        var reference = QRRReferenceGenerator.generate()
        let last = reference.removeLast().wholeNumberValue!
        reference.append(String((last + 1) % 10))
        XCTAssertFalse(QRRReferenceGenerator.isValid(reference))
    }

    func testFormatGroupsAs2Plus5x5() {
        XCTAssertEqual(QRRReferenceGenerator.format("210000000003139471430009017"),
                       "21 00000 00003 13947 14300 09017")
        // Andere Längen unverändert.
        XCTAssertEqual(QRRReferenceGenerator.format("123"), "123")
    }
}

final class XMLEscapingTests: XCTestCase {

    func testEscapesAllFiveSpecialCharacters() {
        XCTAssertEqual(#"a & b < c > d " e ' f"#.xmlEscaped,
                       "a &amp; b &lt; c &gt; d &quot; e &apos; f")
    }

    func testPlainTextUnchanged() {
        XCTAssertEqual("Müller AG, Zürich".xmlEscaped, "Müller AG, Zürich")
    }
}
