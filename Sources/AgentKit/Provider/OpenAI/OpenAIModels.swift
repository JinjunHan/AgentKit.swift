// OpenAIModels.swift
// AgentKit
//

import Foundation

// MARK: - Request Models

/// Top-level request body for the OpenAI Chat Completion API.
struct OpenAIChatRequest: Codable, Sendable {
    let model: String
    let messages: [RequestMessage]
    let tools: [RequestTool]?
    let temperature: Double?
    let maxTokens: Int?
    let topP: Double?
    let stream: Bool?
    let includeReasoning: Bool?

    enum CodingKeys: String, CodingKey {
        case model, messages, tools, temperature
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case stream
        case includeReasoning = "include_reasoning"
    }
}

// MARK: - Request Message

extension OpenAIChatRequest {
    /// A single message in the request conversation.
    struct RequestMessage: Codable, Sendable {
        let role: String
        let content: String?
        let toolCalls: [RequestToolCall]?
        let toolCallID: String?

        enum CodingKeys: String, CodingKey {
            case role, content
            case toolCalls = "tool_calls"
            case toolCallID = "tool_call_id"
        }
    }
}

// MARK: - Request Tool Call

extension OpenAIChatRequest {
    /// A tool call included in an assistant message within the request.
    struct RequestToolCall: Codable, Sendable {
        let id: String
        let type: String
        let function: RequestFunction

        /// The function reference inside a tool call.
        struct RequestFunction: Codable, Sendable {
            let name: String
            let arguments: String
        }

        init(id: String, function: RequestFunction) {
            self.id = id
            self.type = "function"
            self.function = function
        }
    }
}

// MARK: - Request Tool Definition

extension OpenAIChatRequest {
    /// A tool definition attached to the request.
    struct RequestTool: Codable, Sendable {
        let type: String
        let function: FunctionDefinition

        /// The function schema inside a tool definition.
        struct FunctionDefinition: Codable, Sendable {
            let name: String
            let description: String
            let parameters: JSONValue
        }

        init(function: FunctionDefinition) {
            self.type = "function"
            self.function = function
        }
    }
}

// MARK: - Response Models

/// Top-level response from the OpenAI Chat Completion API.
struct OpenAIChatResponse: Codable, Sendable {
    let id: String
    let choices: [Choice]
    let usage: ResponseUsage?

    /// A single choice in the response.
    struct Choice: Codable, Sendable {
        let index: Int
        let message: ResponseMessage
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }

    /// Token usage information.
    struct ResponseUsage: Codable, Sendable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// MARK: - Response Message

extension OpenAIChatResponse.Choice {
    /// The assistant message inside a response choice.
    struct ResponseMessage: Codable, Sendable {
        let role: String?
        let content: String?
        let reasoningContent: String?
        let reasoning: String?
        let toolCalls: [ResponseToolCall]?

        enum CodingKeys: String, CodingKey {
            case role, content
            case reasoningContent = "reasoning_content"
            case reasoning
            case toolCalls = "tool_calls"
        }

        /// A tool call returned by the model.
        struct ResponseToolCall: Codable, Sendable {
            let id: String
            let type: String
            let function: ResponseFunction

            /// Function name and arguments from a response tool call.
            struct ResponseFunction: Codable, Sendable {
                let name: String
                let arguments: String
            }
        }
    }
}

// MARK: - Streaming Response Models

/// A single chunk in a streamed OpenAI response.
struct OpenAIStreamResponse: Codable, Sendable {
    let id: String
    let choices: [StreamChoice]

    /// A choice delta inside a streaming chunk.
    struct StreamChoice: Codable, Sendable {
        let index: Int
        let delta: StreamDelta
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index, delta
            case finishReason = "finish_reason"
        }
    }
}

// MARK: - Stream Delta

extension OpenAIStreamResponse.StreamChoice {
    /// The incremental content inside a streaming choice.
    struct StreamDelta: Codable, Sendable {
        let role: String?
        let content: String?
        let reasoningContent: String?
        let reasoning: String?
        let toolCalls: [StreamToolCall]?

        enum CodingKeys: String, CodingKey {
            case role, content
            case reasoningContent = "reasoning_content"
            case reasoning
            case toolCalls = "tool_calls"
        }

        /// An incremental tool-call update within a stream delta.
        struct StreamToolCall: Codable, Sendable {
            let index: Int
            let id: String?
            let function: StreamFunction?

            /// Incremental function data inside a streaming tool call.
            struct StreamFunction: Codable, Sendable {
                let name: String?
                let arguments: String?
            }
        }
    }
}

// MARK: - Error Response

/// Error response returned by the OpenAI API.
struct OpenAIErrorResponse: Codable, Sendable {
    let error: ErrorDetail

    /// Detailed error information.
    struct ErrorDetail: Codable, Sendable {
        let message: String
        let type: String
        let code: String?
    }
}
