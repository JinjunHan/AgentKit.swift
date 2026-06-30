// ChatResponse.swift
// AgentKit
//

import Foundation

/// The complete response from a non-streaming chat completion request.
///
/// Contains the assistant's ``message``, the ``finishReason`` indicating
/// why generation stopped, and optional token ``usage`` statistics.
public struct ChatResponse: Sendable {

    /// The reason the model stopped generating tokens.
    public enum FinishReason: String, Sendable, Codable {
        /// The model finished naturally or hit a stop sequence.
        case stop

        /// The model is requesting one or more tool calls.
        case toolCalls = "tool_calls"

        /// The response was truncated because it reached the token limit.
        case length

        /// The response was filtered by the provider's content filter.
        case contentFilter = "content_filter"
    }

    /// Token usage statistics for a single request.
    public struct Usage: Sendable {
        /// Number of tokens in the prompt.
        public let promptTokens: Int

        /// Number of tokens in the completion.
        public let completionTokens: Int

        /// Total tokens used (prompt + completion).
        public let totalTokens: Int

        /// Creates a new usage summary.
        ///
        /// - Parameters:
        ///   - promptTokens: Tokens consumed by the prompt.
        ///   - completionTokens: Tokens generated in the completion.
        ///   - totalTokens: Sum of prompt and completion tokens.
        public init(
            promptTokens: Int,
            completionTokens: Int,
            totalTokens: Int
        ) {
            self.promptTokens = promptTokens
            self.completionTokens = completionTokens
            self.totalTokens = totalTokens
        }
    }

    /// The assistant message produced by the model.
    public let message: Message

    /// Why the model stopped generating.
    public let finishReason: FinishReason

    /// Token usage statistics, if provided by the API.
    public let usage: Usage?

    /// Creates a new chat response.
    ///
    /// - Parameters:
    ///   - message: The assistant message.
    ///   - finishReason: The reason generation stopped.
    ///   - usage: Optional token usage statistics.
    public init(
        message: Message,
        finishReason: FinishReason,
        usage: Usage? = nil
    ) {
        self.message = message
        self.finishReason = finishReason
        self.usage = usage
    }
}
