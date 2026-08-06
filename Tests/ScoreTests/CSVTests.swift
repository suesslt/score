import XCTest
@testable import Score

final class CSVTests: XCTestCase {

    // MARK: - String-based Import

    func testParseFromString() throws {
        let csv = "Name;Age;City\nAlice;30;Zurich\nBob;25;Bern"
        let rows = try CSVImporter.parse(from: csv)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["name"], "Alice")
        XCTAssertEqual(rows[0]["age"], "30")
        XCTAssertEqual(rows[1]["city"], "Bern")
    }

    func testParseFromStringComma() throws {
        let csv = "Name,Age\nAlice,30\nBob,25"
        let rows = try CSVImporter.parse(from: csv, separator: ",")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["name"], "Alice")
    }

    func testParseFromStringAutoDetectComma() throws {
        let csv = "Name,Age,City\nAlice,30,Zurich"
        let rows = try CSVImporter.parse(from: csv)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0]["city"], "Zurich")
    }

    func testParseFromStringEmptyThrows() {
        XCTAssertThrowsError(try CSVImporter.parse(from: "")) { error in
            XCTAssertTrue(error is CSVImporter.CSVImportError)
        }
    }

    func testParseFromStringHeaderOnly() {
        XCTAssertThrowsError(try CSVImporter.parse(from: "Name;Age")) { error in
            XCTAssertTrue(error is CSVImporter.CSVImportError)
        }
    }

    // MARK: - RFC 4180 Multiline Quoted Fields

    func testParseMultilineQuotedField() throws {
        let csv = "Name;Description\nAlice;\"Line 1\nLine 2\"\nBob;Simple"
        let rows = try CSVImporter.parse(from: csv)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["description"], "Line 1\nLine 2")
        XCTAssertEqual(rows[1]["name"], "Bob")
    }

    func testParseEscapedQuotes() throws {
        let csv = "Name;Value\nTest;\"He said \"\"hello\"\"\""
        let rows = try CSVImporter.parse(from: csv)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0]["value"], "He said \"hello\"")
    }

    func testParseBOMStripped() throws {
        let csv = "\u{FEFF}Name;Age\nAlice;30"
        let rows = try CSVImporter.parse(from: csv)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0]["name"], "Alice")
    }

    // MARK: - Row-Level Error Tracking

    func testParseWithErrorsSuccess() throws {
        let csv = "Name;Age\nAlice;30\nBob;25"
        let result = try CSVImporter.parseWithErrors(from: csv) { row -> (String, Int) in
            guard let name = row["name"], let ageStr = row["age"], let age = Int(ageStr) else {
                throw CSVImporter.CSVImportError.emptyFile
            }
            return (name, age)
        }
        XCTAssertEqual(result.valid.count, 2)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.valid[0].0, "Alice")
        XCTAssertEqual(result.valid[1].1, 25)
    }

    func testParseWithErrorsPartialFailure() throws {
        let csv = "Name;Age\nAlice;30\nBob;invalid\nCharlie;40"
        let result = try CSVImporter.parseWithErrors(from: csv) { row -> (String, Int) in
            guard let name = row["name"], let ageStr = row["age"], let age = Int(ageStr) else {
                throw CSVImporter.CSVImportError.emptyFile
            }
            return (name, age)
        }
        XCTAssertEqual(result.valid.count, 2)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(result.errors[0].lineNumber, 3) // 1-based: header=1, Alice=2, Bob=3
        XCTAssertTrue(result.hasErrors)
        XCTAssertEqual(result.totalCount, 3)
    }

    func testParseWithErrorsMissingColumns() {
        let csv = "Name;Age\nAlice;30"
        XCTAssertThrowsError(
            try CSVImporter.parseWithErrors(from: csv, required: ["name", "email"]) { $0 }
        )
    }

    // MARK: - String-based Export

    func testExportCSVString() {
        struct Item: CSVExportable {
            let name: String
            let age: Int
            static var exportColumns: [ExportColumn] {
                [ExportColumn("Name"), ExportColumn("Age")]
            }
            var exportValues: [String] {
                [name, "\(age)"]
            }
        }

        let items = [Item(name: "Alice", age: 30), Item(name: "Bob", age: 25)]
        let csv = CSVExporter.exportCSVString(data: items)
        XCTAssertTrue(csv.hasPrefix("Name;Age\n"))
        XCTAssertTrue(csv.contains("Alice;30\n"))
        XCTAssertTrue(csv.contains("Bob;25\n"))
    }

    func testExportCSVStringComma() {
        struct Item: CSVExportable {
            static var exportColumns: [ExportColumn] { [ExportColumn("A"), ExportColumn("B")] }
            var exportValues: [String] { ["x", "y"] }
        }
        let csv = CSVExporter.exportCSVString(data: [Item()], separator: ",")
        XCTAssertTrue(csv.hasPrefix("A,B\n"))
    }

    // MARK: - Roundtrip

    func testRoundtrip() throws {
        struct Item: CSVExportable, Equatable {
            let name: String
            let value: String
            static var exportColumns: [ExportColumn] {
                [ExportColumn("Name"), ExportColumn("Value")]
            }
            var exportValues: [String] { [name, value] }
        }

        let original = [
            Item(name: "Alice", value: "Hello, World"),
            Item(name: "Bob", value: "Line1\nLine2"),
            Item(name: "Charlie", value: "He said \"hi\"")
        ]

        let csv = CSVExporter.exportCSVString(data: original)
        let rows = try CSVImporter.parse(from: csv)

        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0]["name"], "Alice")
        XCTAssertEqual(rows[0]["value"], "Hello, World")
        XCTAssertEqual(rows[1]["value"], "Line1\nLine2")
        XCTAssertEqual(rows[2]["value"], "He said \"hi\"")
    }

    // MARK: - Parsing Helpers

    func testParseDate() {
        XCTAssertNotNil(CSVImporter.parseDate("15.03.2024"))
        XCTAssertNotNil(CSVImporter.parseDate("2024-03-15"))
        XCTAssertNil(CSVImporter.parseDate(""))
        XCTAssertNil(CSVImporter.parseDate("invalid"))
    }

    func testParseDecimal() {
        XCTAssertEqual(CSVImporter.parseDecimal("1234.56"), Decimal(string: "1234.56"))
        XCTAssertEqual(CSVImporter.parseDecimal("1234,56"), Decimal(string: "1234.56"))
        XCTAssertEqual(CSVImporter.parseDecimal("1'234.56"), Decimal(string: "1234.56"))
        XCTAssertNil(CSVImporter.parseDecimal(""))
    }
}

// MARK: - v2.2.0 additions (Data parsing, exact-case headers, parseFlag)

extension CSVTests {

    func testParseFromDataUTF8() throws {
        let data = Data("name;city\nÜli;Zürich\n".utf8)
        let rows = try CSVImporter.parse(from: data)
        XCTAssertEqual(rows, [["name": "Üli", "city": "Zürich"]])
    }

    func testParseFromDataLatin1Fallback() throws {
        let data = "name;city\nMüller;Zürich\n".data(using: .isoLatin1)!
        XCTAssertNil(String(data: data, encoding: .utf8))
        let rows = try CSVImporter.parse(from: data)
        XCTAssertEqual(rows, [["name": "Müller", "city": "Zürich"]])
    }

    func testDecodeInvalidEncodingThrows() {
        // UTF-16 with BOM decodes neither as UTF-8 nor meaningfully — but isoLatin1
        // accepts any byte sequence, so decode() can only fail for byte patterns
        // isoLatin1 rejects; there are none. Verify the fallback path instead.
        let data = "Grüezi".data(using: .isoLatin1)!
        XCTAssertEqual(try? CSVImporter.decode(data), "Grüezi")
    }

    func testParseExactCaseHeaders() throws {
        let rows = try CSVImporter.parse(from: "eventName,eventDate\nGV,2026-01-01\n",
                                         lowercasedHeaders: false)
        XCTAssertEqual(rows, [["eventName": "GV", "eventDate": "2026-01-01"]])
    }

    func testParseWithErrorsExactCaseHeaders() throws {
        let result = try CSVImporter.parseWithErrors(
            from: "keyMessage,subject\nA,B\n,C\n",
            required: ["keyMessage"],
            lowercasedHeaders: false
        ) { row -> String in
            guard let message = row["keyMessage"], !message.isEmpty else {
                throw CSVImporter.CSVImportError.emptyFile
            }
            return message
        }
        XCTAssertEqual(result.valid, ["A"])
        XCTAssertEqual(result.errors.map(\.lineNumber), [3])
    }

    func testParseFlag() {
        XCTAssertTrue(CSVImporter.parseFlag("true"))
        XCTAssertTrue(CSVImporter.parseFlag("Ja"))
        XCTAssertTrue(CSVImporter.parseFlag("1"))
        XCTAssertFalse(CSVImporter.parseFlag("false"))
        XCTAssertFalse(CSVImporter.parseFlag(""))
        XCTAssertFalse(CSVImporter.parseFlag(nil))
    }

    func testParseDecimalStripsApostropheVariants() {
        XCTAssertEqual(CSVImporter.parseDecimal("1'234.50"), Decimal(string: "1234.50"))
        XCTAssertEqual(CSVImporter.parseDecimal("1\u{2019}234,50"), Decimal(string: "1234.50"))
        XCTAssertEqual(CSVImporter.parseDecimal("1\u{2018}234.50"), Decimal(string: "1234.50"))
        XCTAssertEqual(CSVImporter.parseDecimal("1\u{02BC}234.50"), Decimal(string: "1234.50"))
    }
}
