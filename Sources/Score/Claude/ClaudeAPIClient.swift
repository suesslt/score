//
//  ClaudeAPIClient.swift
//  Score
//
//  Reusable HTTP client for the Claude Messages API.
//

import Foundation

/// A lightweight, reusable client for the Anthropic Claude Messages API.
///
/// Usage:
/// ```swift
/// let client = ClaudeAPIClient(apiKey: "sk-...")
/// let config = ClaudeRequestConfig(model: "claude-sonnet-4-6", maxTokens: 4096)
/// let response = try await client.sendMessage("Hello", config: config)
/// let text = response.textContent
/// ```
public struct ClaudeAPIClient: Sendable {

    private static let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let anthropicVersion = "2023-06-01"

    private let apiKey: String
    private let session: URLSession

    /// Creates a new Claude API client.
    ///
    /// - Parameters:
    ///   - apiKey: The Anthropic API key.
    ///   - session: The URL session to use for requests. Defaults to `.shared`.
    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Public API

    /// Sends a single user message and returns the API response.
    ///
    /// - Parameters:
    ///   - content: The user message content.
    ///   - config: Request configuration (model, max tokens, system prompt, tools).
    /// - Returns: The parsed API response.
    public func sendMessage(
        _ content: String,
        config: ClaudeRequestConfig
    ) async throws -> ClaudeAPIResponse {
        try await send(messages: [.user(content)], config: config)
    }

    /// Sends a conversation (multiple messages) and returns the API response.
    ///
    /// - Parameters:
    ///   - messages: The conversation messages.
    ///   - config: Request configuration (model, max tokens, system prompt, tools).
    /// - Returns: The parsed API response.
    public func send(
        messages: [ClaudeMessage],
        config: ClaudeRequestConfig
    ) async throws -> ClaudeAPIResponse {
        let request = try buildRequest(messages: messages, config: config)
        return try await execute(request)
    }

    /// Sends a message and decodes a structured response from the text content.
    ///
    /// Combines sending the request with JSON extraction and decoding.
    ///
    /// - Parameters:
    ///   - content: The user message content.
    ///   - config: Request configuration.
    ///   - type: The expected response type.
    ///   - expectArray: Whether the JSON response is an array.
    /// - Returns: The decoded value.
    public func sendAndDecode<T: Decodable>(
        _ content: String,
        config: ClaudeRequestConfig,
        as type: T.Type,
        expectArray: Bool = false
    ) async throws -> T {
        let response = try await sendMessage(content, config: config)
        let text = response.textContent
        guard !text.isEmpty else {
            throw ClaudeAPIError.noContent
        }
        return try ClaudeResponseParser.decode(type, from: text, expectArray: expectArray)
    }

    // MARK: - Private

    private func buildRequest(
        messages: [ClaudeMessage],
        config: ClaudeRequestConfig
    ) throws -> URLRequest {
        var request = URLRequest(url: Self.apiURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = config.timeoutInterval

        let body = ClaudeRequestBody(
            model: config.model,
            max_tokens: config.maxTokens,
            system: config.systemPrompt,
            tools: config.tools.isEmpty ? nil : config.tools,
            messages: messages
        )

        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func execute(_ request: URLRequest) async throws -> ClaudeAPIResponse {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ClaudeAPIError.networkError(underlying: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.networkError(underlying: "Keine HTTP-Antwort erhalten")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unbekannter Fehler"
            throw ClaudeAPIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        return try JSONDecoder().decode(ClaudeAPIResponse.self, from: data)
    }
}
