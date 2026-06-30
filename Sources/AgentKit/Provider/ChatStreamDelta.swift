// ChatStreamDelta.swift
// AgentKit
//

import Foundation

/// An incremental chunk received during a streaming chat completion.
///
/// Each delta may contain partial content text, partial tool-call information,
/// or a finish reason signaling the end of the stream.
public struct ChatStreamDelta: Sendable {

    /// An incremental update to a single tool call within a streaming response.
    public struct ToolCallDelta: Sendable {
        /// The index of the tool call this delta belongs to.
        public let index: Int

        /// The tool-call ID, present only in the first delta for this index.
        public let id: String?

        /// The function name, present only in the first delta for this index.
        public let functionName: String?

        /// An incremental fragment of the JSON arguments string.
        public let argumentsDelta: String?

        /// Creates a new tool-call delta.
        ///
        /// - Parameters:
        ///   - index: Index of the tool call in the response.
        ///   - id: Tool-call ID (first chunk only).
        ///   - functionName: Function name (first chunk only).
        ///   - argumentsDelta: Incremental arguments fragment.
        public init(
            index: Int,
            id: String? = nil,
            functionName: String? = nil,
            argumentsDelta: String? = nil
        ) {
            self.index = index
            self.id = id
            self.functionName = functionName
            self.argumentsDelta = argumentsDelta
        }
    }

    /// Incremental content text, if any.
    public let deltaContent: String?

    /// Incremental reasoning/thinking content, if any.
    public let deltaReasoningContent: String?

    /// Incremental tool-call updates, if any.
    public let deltaToolCalls: [ToolCallDelta]?

    /// The finish reason, present only on the final chunk.
    public let finishReason: ChatResponse.FinishReason?

    /// Creates a new stream delta.
    ///
    /// - Parameters:
    ///   - deltaContent: Partial content text.
    ///   - deltaReasoningContent: Partial reasoning/thinking text.
    ///   - deltaToolCalls: Partial tool-call updates.
    ///   - finishReason: Finish reason (final chunk only).
    public init(
        deltaContent: String? = nil,
        deltaReasoningContent: String? = nil,
        deltaToolCalls: [ToolCallDelta]? = nil,
        finishReason: ChatResponse.FinishReason? = nil
    ) {
        self.deltaContent = deltaContent
        self.deltaReasoningContent = deltaReasoningContent
        self.deltaToolCalls = deltaToolCalls
        self.finishReason = finishReason
    }
}
