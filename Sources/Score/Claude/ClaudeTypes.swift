//
//  ClaudeTypes.swift
//  Score
//
//  Shared types for Claude API integration.
//

import Foundation

// MARK: - Request Types

/// Configuration for a Claude API request.
public struct ClaudeRequestConfig: Sendable {
    public let model: String
    public let maxTokens: Int
    public let systemPrompt: String?
    public let tools: [ClaudeTool]
    public let timeoutInterval: TimeInterval

    public init(
        model: String,
        maxTokens: Int = 4096,
        systemPrompt: String? = nil,
        tools: [ClaudeTool] = [],
        timeoutInterval: TimeInterval = 120
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.timeoutInterval = timeoutInterval
    }
}

/// A tool that Claude can use during generation.
public struct ClaudeTool: Sendable, Encodable {
    public let type: String
    public let name: String
    public let maxUses: Int

    public init(type: String, name: String, maxUses: Int) {
        self.type = type
        self.name = name
        self.maxUses = maxUses
    }

    enum CodingKeys: String, CodingKey {
        case type, name
        case maxUses = "max_uses"
    }

    /// Web search tool with configurable max uses.
    public static func webSearch(maxUses: Int = 5) -> ClaudeTool {
        ClaudeTool(type: "web_search_20250305", name: "web_search", maxUses: maxUses)
    }
}

/// A message in the Claude conversation.
public struct ClaudeMessage: Sendable, Codable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }

    /// Creates a user message.
    public static func user(_ content: String) -> ClaudeMessage {
        ClaudeMessage(role: "user", content: content)
    }

    /// Creates an assistant message.
    public static func assistant(_ content: String) -> ClaudeMessage {
        ClaudeMessage(role: "assistant", content: content)
    }
}

// MARK: - Response Types

/// Top-level response from the Claude API.
public struct ClaudeAPIResponse: Sendable, Decodable {
    public let id: String?
    public let type: String?
    public let role: String?
    public let content: [ClaudeContentBlock]
    public let model: String?
    public let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
    }

    /// Extracts all text content from the response, joined by newline.
    public var textContent: String {
        content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined(separator: "\n")
    }
}

/// A content block within a Claude response.
public struct ClaudeContentBlock: Sendable, Decodable {
    public let type: String
    public let text: String?
}

// MARK: - Error Types

/// Errors that can occur when communicating with the Claude API.
public enum ClaudeAPIError: LocalizedError, Sendable {
    case invalidURL
    case noAPIKey
    case networkError(underlying: String)
    case apiError(statusCode: Int, message: String)
    case noContent
    case jsonParsingFailed(detail: String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ungueltige API-URL."
        case .noAPIKey:
            return "Kein API-Key konfiguriert."
        case .networkError(let underlying):
            return "Netzwerkfehler: \(underlying)"
        case .apiError(let code, let message):
            return "API-Fehler (\(code)): \(String(message.prefix(200)))"
        case .noContent:
            return "Keine Text-Inhalte in der Claude-Antwort."
        case .jsonParsingFailed(let detail):
            return "JSON konnte nicht geparst werden: \(detail)"
        }
    }
}

// MARK: - Internal Request DTO (for encoding)

struct ClaudeRequestBody: Encodable {
    let model: String
    let max_tokens: Int
    let system: String?
    let tools: [ClaudeTool]?
    let messages: [ClaudeMessage]

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(max_tokens, forKey: .max_tokens)
        try container.encodeIfPresent(system, forKey: .system)
        if let tools, !tools.isEmpty {
            try container.encode(tools, forKey: .tools)
        }
        try container.encode(messages, forKey: .messages)
    }

    enum CodingKeys: String, CodingKey {
        case model, max_tokens, system, tools, messages
    }
}
