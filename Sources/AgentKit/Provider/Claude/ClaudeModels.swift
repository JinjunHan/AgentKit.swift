// ClaudeModels.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

// MARK: - Request Models

struct ClaudeMessageRequest: Encodable, Sendable {
    let model: String
    let system: String?
    let messages: [ClaudeMessage]
    let tools: [ClaudeTool]?
    let maxTokens: Int
    let temperature: Double?
    let stream: Bool?

    enum CodingKeys: String, CodingKey {
        case model, system, messages, tools, stream
        case maxTokens = "max_tokens"
        case temperature
    }
}

struct ClaudeMessage: Encodable, Sendable {
    let role: String
    let content: [ClaudeContentBlock]
}

enum ClaudeContentBlock: Encodable, Sendable {
    case text(String)
    case toolUse(id: String, name: String, input: JSONValue)
    case toolResult(toolUseID: String, content: String)

    enum CodingKeys: String, CodingKey {
        case type, text, id, name, input, content
        case toolUseID = "tool_use_id"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .toolUse(let id, let name, let input):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(input, forKey: .input)
        case .toolResult(let toolUseID, let content):
            try container.encode("tool_result", forKey: .type)
            try container.encode(toolUseID, forKey: .toolUseID)
            try container.encode(content, forKey: .content)
        }
    }
}

struct ClaudeTool: Encodable, Sendable {
    let name: String
    let description: String
    let inputSchema: JSONValue

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

// MARK: - Response Models

struct ClaudeMessageResponse: Decodable, Sendable {
    let id: String
    let role: String
    let content: [ClaudeResponseContentBlock]
    let stopReason: String?
    let usage: ClaudeUsage?

    enum CodingKeys: String, CodingKey {
        case id, role, content, usage
        case stopReason = "stop_reason"
    }
}

struct ClaudeResponseContentBlock: Decodable, Sendable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let input: JSONValue?
}

struct ClaudeUsage: Decodable, Sendable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - Stream Models

struct ClaudeStreamResponse: Decodable, Sendable {
    let type: String
    let index: Int?
    let delta: ClaudeStreamDelta?
    let message: ClaudeMessageResponse?
    let contentBlock: ClaudeResponseContentBlock?

    enum CodingKeys: String, CodingKey {
        case type, index, delta, message
        case contentBlock = "content_block"
    }
}

struct ClaudeStreamDelta: Decodable, Sendable {
    let type: String?
    let text: String?
    let partialJson: String?
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case type, text
        case partialJson = "partial_json"
        case stopReason = "stop_reason"
    }
}

// MARK: - Error Response

struct ClaudeErrorResponse: Decodable, Sendable {
    let error: ErrorDetail

    struct ErrorDetail: Decodable, Sendable {
        let type: String
        let message: String
    }
}
