// FoundationModelsChatProvider.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// A ``ChatProvider`` implementation powered by Apple's on-device Foundation Models framework.
///
/// Runs entirely on-device with no API key required. Available on iOS 26+ and macOS 26+.
///
/// > Important: Tool calling is not supported via this provider because Apple's
/// > `FoundationModels.Tool` protocol requires `@Generable` argument types at compile time,
/// > which cannot be dynamically bridged from AgentKit's JSON-based tool definitions.
/// > If you need tool calling, use ``OpenAIChatProvider`` or ``ClaudeChatProvider``.
///
/// ## Usage
/// ```swift
/// let provider = FoundationModelsChatProvider()
/// let agent = try AgentBuilder()
///     .provider(provider, configuration: ProviderConfiguration.onDevice())
///     .systemPrompt("You are a helpful assistant.")
///     .build()
/// ```
@available(iOS 26.0, macOS 26.0, *)
public struct FoundationModelsChatProvider: ChatProvider {

    // MARK: - Init

    /// Creates a new Foundation Models on-device chat provider.
    public init() {}

    // MARK: - ChatProvider Conformance

    public func sendChat(
        messages: [Message],
        tools: [any AgentKit.Tool],
        configuration: ProviderConfiguration
    ) async throws(AgentKitError) -> ChatResponse {
        let session = makeSession(from: messages)

        guard let lastUserMessage = messages.last(where: { $0.role == .user }),
              let prompt = lastUserMessage.content else {
            throw .invalidConfiguration("No user message found in conversation")
        }

        let responseText: String
        do {
            let response = try await session.respond(to: prompt)
            responseText = response.content
        } catch {
            throw .providerError("Foundation Models error: \(error.localizedDescription)")
        }

        let message = Message.assistant(responseText)
        return ChatResponse(
            message: message,
            finishReason: .stop,
            usage: nil
        )
    }

    public func streamChat(
        messages: [Message],
        tools: [any AgentKit.Tool],
        configuration: ProviderConfiguration
    ) -> AsyncThrowingStream<ChatStreamDelta, any Error> {
        let session = makeSession(from: messages)

        guard let lastUserMessage = messages.last(where: { $0.role == .user }),
              let prompt = lastUserMessage.content else {
            return AsyncThrowingStream { continuation in
                continuation.finish(
                    throwing: AgentKitError.invalidConfiguration("No user message found in conversation")
                )
            }
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let stream = session.streamResponse(to: prompt)
                    var lastContent = ""

                    for try await partial in stream {
                        let currentContent = partial.content
                        if currentContent.count > lastContent.count {
                            let delta = String(currentContent.dropFirst(lastContent.count))
                            continuation.yield(ChatStreamDelta(deltaContent: delta))
                        }
                        lastContent = currentContent
                    }

                    continuation.yield(ChatStreamDelta(finishReason: .stop))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Private

    private func makeSession(from messages: [Message]) -> LanguageModelSession {
        let systemInstructions = messages
            .filter { $0.role == .system }
            .compactMap { $0.content }
            .joined(separator: "\n\n")

        let instructions = systemInstructions.isEmpty ? nil : systemInstructions

        if let instructions {
            return LanguageModelSession(instructions: instructions)
        } else {
            return LanguageModelSession()
        }
    }
}

#endif

// MARK: - ProviderConfiguration Extension

extension ProviderConfiguration {

    /// Creates a configuration suitable for the on-device Foundation Models provider.
    ///
    /// No API key or base URL is required for on-device inference.
    ///
    /// - Returns: A ``ProviderConfiguration`` with placeholder values for on-device use.
    public static func onDevice() -> ProviderConfiguration {
        ProviderConfiguration(
            apiKey: "",
            baseURL: "",
            model: "apple-on-device"
        )
    }
}
