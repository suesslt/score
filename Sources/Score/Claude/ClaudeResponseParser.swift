//
//  ClaudeResponseParser.swift
//  Score
//
//  Utilities for extracting structured data from Claude API responses.
//

import Foundation

/// Parses structured data from Claude API text responses.
public enum ClaudeResponseParser: Sendable {

    // MARK: - JSON Extraction

    /// Extracts a JSON string from Claude's response text.
    ///
    /// Tries in order:
    /// 1. ```json ... ``` code block
    /// 2. ``` ... ``` code block
    /// 3. Raw JSON (first `{`/`[` to last `}`/`]`)
    ///
    /// - Parameters:
    ///   - text: The raw text from Claude's response.
    ///   - expectArray: If `true`, looks for `[...]`; if `false`, looks for `{...}`.
    /// - Returns: The extracted JSON string, or `nil` if no JSON found.
    public static func extractJSON(from text: String, expectArray: Bool = false) -> String? {
        // Try ```json ... ``` code block
        if let result = extractFromCodeBlock(text, language: "json") {
            return result
        }

        // Try ``` ... ``` code block
        if let result = extractFromCodeBlock(text, language: nil) {
            return result
        }

        // Try raw JSON boundaries
        let openChar: Character = expectArray ? "[" : "{"
        let closeChar: Character = expectArray ? "]" : "}"

        if let start = text.firstIndex(of: openChar),
           let end = text.lastIndex(of: closeChar),
           start < end {
            return String(text[start...end])
        }

        return nil
    }

    /// Decodes a `Decodable` type from Claude's response text.
    ///
    /// Extracts JSON from the text and decodes it into the specified type.
    ///
    /// - Parameters:
    ///   - type: The type to decode.
    ///   - text: The raw text from Claude's response.
    ///   - expectArray: Whether the JSON is expected to be an array.
    /// - Returns: The decoded value.
    /// - Throws: `ClaudeAPIError.jsonParsingFailed` if extraction or decoding fails.
    public static func decode<T: Decodable>(
        _ type: T.Type,
        from text: String,
        expectArray: Bool = false
    ) throws -> T {
        guard let jsonString = extractJSON(from: text, expectArray: expectArray) else {
            throw ClaudeAPIError.jsonParsingFailed(detail: "Kein JSON in Antwort gefunden")
        }

        guard let data = jsonString.data(using: .utf8) else {
            throw ClaudeAPIError.jsonParsingFailed(detail: "Ungueltige Zeichenkodierung")
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw ClaudeAPIError.jsonParsingFailed(detail: String(jsonString.prefix(200)))
        }
    }

    // MARK: - Private Helpers

    private static func extractFromCodeBlock(_ text: String, language: String?) -> String? {
        let marker = language.map { "```\($0)" } ?? "```"

        guard let startRange = text.range(of: marker) else { return nil }
        guard let contentStart = text.range(of: "\n", range: startRange.upperBound..<text.endIndex) else { return nil }

        let searchRange = contentStart.upperBound..<text.endIndex
        guard let endRange = text.range(of: "```", range: searchRange) else { return nil }

        return String(text[contentStart.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
