// ChatProvider.swift
// AgentKit
//

import Foundation

/// A provider that communicates with an LLM service to produce chat completions.
///
/// Conform to this protocol to integrate a new LLM backend (e.g., OpenAI, Anthropic).
/// AgentKit ships with ``OpenAIChatProvider`` as the default implementation.
///
/// Both blocking and streaming interfaces are required:
/// - ``sendChat(messages:tools:configuration:)`` returns a complete ``ChatResponse``.
/// - ``streamChat(messages:tools:configuration:)`` returns an ``AsyncThrowingStream``
///   of ``ChatStreamDelta`` values for incremental processing.
public protocol ChatProvider: Sendable {
    /// Send a chat completion request and receive a complete response.
    ///
    /// - Parameters:
    ///   - messages: The conversation history to send.
    ///   - tools: Tools the model may call.
    ///   - configuration: Provider-specific settings (model, API key, etc.).
    /// - Returns: A ``ChatResponse`` containing the assistant's message.
    /// - Throws: ``AgentKitError`` on failure.
    func sendChat(
        messages: [Message],
        tools: [any Tool],
        configuration: ProviderConfiguration
    ) async throws(AgentKitError) -> ChatResponse

    /// Send a chat completion request and receive a streaming response.
    ///
    /// - Parameters:
    ///   - messages: The conversation history to send.
    ///   - tools: Tools the model may call.
    ///   - configuration: Provider-specific settings (model, API key, etc.).
    /// - Returns: An asynchronous stream of ``ChatStreamDelta`` values.
    func streamChat(
        messages: [Message],
        tools: [any Tool],
        configuration: ProviderConfiguration
    ) -> AsyncThrowingStream<ChatStreamDelta, any Error>
}
