import XCTest
@testable import Score

final class ClaudeResponseParserTests: XCTestCase {

    // MARK: - JSON Extraction from code blocks

    func testExtractJSONFromJsonCodeBlock() {
        let text = """
        Here is the result:
        ```json
        {"name": "test", "value": 42}
        ```
        That's the output.
        """
        let result = ClaudeResponseParser.extractJSON(from: text)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("\"name\""))
        XCTAssertTrue(result!.contains("\"test\""))
    }

    func testExtractJSONFromPlainCodeBlock() {
        let text = """
        ```
        {"key": "value"}
        ```
        """
        let result = ClaudeResponseParser.extractJSON(from: text)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("\"key\""))
    }

    func testExtractJSONRawObject() {
        let text = "Some text before {\"a\": 1, \"b\": 2} and after"
        let result = ClaudeResponseParser.extractJSON(from: text)
        XCTAssertEqual(result, "{\"a\": 1, \"b\": 2}")
    }

    func testExtractJSONRawArray() {
        let text = "Result: [{\"id\": 1}, {\"id\": 2}] end"
        let result = ClaudeResponseParser.extractJSON(from: text, expectArray: true)
        XCTAssertEqual(result, "[{\"id\": 1}, {\"id\": 2}]")
    }

    func testExtractJSONReturnsNilForNoJSON() {
        let text = "This is plain text with no JSON at all."
        let result = ClaudeResponseParser.extractJSON(from: text)
        XCTAssertNil(result)
    }

    func testExtractJSONPrefersCodeBlockOverRaw() {
        let text = """
        Some {invalid} stuff
        ```json
        {"correct": true}
        ```
        More {stuff}
        """
        let result = ClaudeResponseParser.extractJSON(from: text)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("\"correct\""))
    }

    // MARK: - Decode

    struct TestDTO: Decodable, Equatable {
        let name: String
        let value: Int
    }

    func testDecodeFromCodeBlock() throws {
        let text = """
        ```json
        {"name": "hello", "value": 99}
        ```
        """
        let result = try ClaudeResponseParser.decode(TestDTO.self, from: text)
        XCTAssertEqual(result, TestDTO(name: "hello", value: 99))
    }

    func testDecodeArrayFromText() throws {
        let text = """
        Here are the results:
        ```json
        [{"name": "a", "value": 1}, {"name": "b", "value": 2}]
        ```
        """
        let result = try ClaudeResponseParser.decode([TestDTO].self, from: text, expectArray: true)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].name, "a")
        XCTAssertEqual(result[1].value, 2)
    }

    func testDecodeThrowsOnInvalidJSON() {
        let text = "No JSON here"
        XCTAssertThrowsError(try ClaudeResponseParser.decode(TestDTO.self, from: text)) { error in
            XCTAssertTrue(error is ClaudeAPIError)
        }
    }

    func testDecodeThrowsOnMalformedJSON() {
        let text = """
        ```json
        {"name": "test", "value": "not_an_int"}
        ```
        """
        XCTAssertThrowsError(try ClaudeResponseParser.decode(TestDTO.self, from: text)) { error in
            XCTAssertTrue(error is ClaudeAPIError)
        }
    }

    // MARK: - ClaudeAPIResponse textContent

    func testAPIResponseTextContent() throws {
        let json = """
        {
            "content": [
                {"type": "text", "text": "Hello"},
                {"type": "tool_use", "text": null},
                {"type": "text", "text": "World"}
            ]
        }
        """
        let response = try JSONDecoder().decode(ClaudeAPIResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.textContent, "Hello\nWorld")
    }

    func testAPIResponseTextContentEmpty() throws {
        let json = """
        {"content": [{"type": "tool_use"}]}
        """
        let response = try JSONDecoder().decode(ClaudeAPIResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.textContent, "")
    }
}
