// OpenAIChatProvider.swift
// AgentKit
//

import Foundation

/// A ``ChatProvider`` implementation that communicates with the OpenAI Chat
/// Completion API (or any API-compatible service).
///
/// Supports both blocking (``sendChat(messages:tools:configuration:)``) and
/// streaming (``streamChat(messages:tools:configuration:)``) interactions.
///
/// ```swift
/// let provider = OpenAIChatProvider()
/// let response = try await provider.sendChat(
///     messages: [.user("Hello!")],
///     tools: [],
///     configuration: ProviderConfiguration(apiKey: "sk-...")
/// )
/// ```
public struct OpenAIChatProvider: ChatProvider {

    // MARK: - Properties

    private let session: URLSession

    // MARK: - Init

    /// Creates a new OpenAI chat provider.
    ///
    /// - Parameter session: The `URLSession` to use for network requests.
    ///   Defaults to `.shared`.
    public init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - ChatProvider Conformance

    /// Send a chat completion request and receive a complete response.
    ///
    /// - Parameters:
    ///   - messages: The conversation history.
    ///   - tools: Tools the model may invoke.
    ///   - configuration: Provider settings (API key, model, etc.).
    /// - Returns: A ``ChatResponse`` with the assistant's reply.
    /// - Throws: ``AgentKitError`` on network or decoding failures.
    public func sendChat(
        messages: [Message],
        tools: [any Tool],
        configuration: ProviderConfiguration
    ) async throws(AgentKitError) -> ChatResponse {
        let body = buildRequest(
            messages: messages,
            tools: tools,
            configuration: configuration,
            stream: false
        )

        let urlRequest: URLRequest
        do {
            urlRequest = try await makeURLRequest(
                configuration: configuration,
                body: body
            )
        } catch let error as AgentKitError {
            throw error
        } catch {
            throw .providerError(error.localizedDescription)
        }

        let data: Data
        let httpResponse: HTTPURLResponse
        do {
            let (responseData, response) = try await session.data(for: urlRequest)
            data = responseData
            guard let resp = response as? HTTPURLResponse else {
                throw AgentKitError.networkError("Invalid response type")
            }
            httpResponse = resp
        } catch let error as AgentKitError {
            throw error
        } catch {
            throw .networkError(error.localizedDescription)
        }

        // Check for an API-level error on non-2xx status codes.
        if httpResponse.statusCode >= 400 {
            if let apiError = try? JSONDecoder().decode(
                OpenAIErrorResponse.self, from: data
            ) {
                throw .providerError(apiError.error.message)
            }
            throw .providerError(
                "HTTP \(httpResponse.statusCode)"
            )
        }

        let decoded: OpenAIChatResponse
        do {
            decoded = try JSONDecoder().decode(
                OpenAIChatResponse.self, from: data
            )
        } catch {
            throw .encodingError(
                "Failed to decode OpenAI response: \(error.localizedDescription)"
            )
        }

        return try convertResponse(decoded)
    }

    /// Send a chat completion request and receive a streaming response.
    ///
    /// - Parameters:
    ///   - messages: The conversation history.
    ///   - tools: Tools the model may invoke.
    ///   - configuration: Provider settings (API key, model, etc.).
    /// - Returns: An asynchronous stream of ``ChatStreamDelta`` values.
    public func streamChat(
        messages: [Message],
        tools: [any Tool],
        configuration: ProviderConfiguration
    ) -> AsyncThrowingStream<ChatStreamDelta, any Error> {
        let body = buildRequest(
            messages: messages,
            tools: tools,
            configuration: configuration,
            stream: true
        )

        let capturedSession = session

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = try await makeURLRequest(
                        configuration: configuration,
                        body: body
                    )
                    
                    let (bytes, response) = try await capturedSession.bytes(
                        for: urlRequest
                    )
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode >= 400 {
                        // Collect error body for diagnostics
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                        }
                        if let apiError = try? JSONDecoder().decode(
                            OpenAIErrorResponse.self,
                            from: Data(errorBody.utf8)
                        ) {
                            continuation.finish(
                                throwing: AgentKitError.providerError(
                                    apiError.error.message
                                )
                            )
                        } else {
                            continuation.finish(
                                throwing: AgentKitError.providerError(
                                    "HTTP \(httpResponse.statusCode)"
                                )
                            )
                        }
                        return
                    }
                    for try await response in SSEParser.events(
                        from: bytes,
                        decodingType: OpenAIStreamResponse.self
                    ) {
                        let delta = convertStreamResponse(response)
                        continuation.yield(delta)
                    }
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

    // MARK: - Request Building

    /// Builds the internal request model from public types.
    private func buildRequest(
        messages: [Message],
        tools: [any Tool],
        configuration: ProviderConfiguration,
        stream: Bool
    ) -> OpenAIChatRequest {
        let requestMessages = messages.map { convertMessage($0) }

        let requestTools: [OpenAIChatRequest.RequestTool]? =
            tools.isEmpty ? nil : tools.map { convertTool($0) }

        return OpenAIChatRequest(
            model: configuration.model,
            messages: requestMessages,
            tools: requestTools,
            temperature: configuration.temperature,
            maxTokens: configuration.maxTokens,
            topP: configuration.topP,
            stream: stream ? true : nil,
            includeReasoning: true
        )
    }

    /// Creates a configured `URLRequest` from the configuration and body,
    /// and applies any configured interceptors.
    private func makeURLRequest(
        configuration: ProviderConfiguration,
        body: OpenAIChatRequest
    ) async throws -> URLRequest {
        let urlString = "\(configuration.baseURL)/v1/chat/completions"
        guard let url = URL(string: urlString) else {
            throw AgentKitError.invalidConfiguration(
                "Invalid base URL: \(configuration.baseURL)"
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Bearer \(configuration.apiKey)",
            forHTTPHeaderField: "Authorization"
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw AgentKitError.encodingError(
                "Failed to encode request: \(error.localizedDescription)"
            )
        }

        // Apply interceptor chain
        if !configuration.interceptors.isEmpty {
            let chain = InterceptorChain(interceptors: configuration.interceptors)
            do {
                request = try await chain.execute(request: request)
            } catch {
                throw AgentKitError.providerError(
                    "Interceptor failed: \(error.localizedDescription)"
                )
            }
        }

        return request
    }

    // MARK: - Message Conversion

    /// Converts a public ``Message`` to the internal request representation.
    private func convertMessage(
        _ message: Message
    ) -> OpenAIChatRequest.RequestMessage {
        let toolCalls: [OpenAIChatRequest.RequestToolCall]? =
            message.toolCalls.isEmpty
            ? nil
            : message.toolCalls.map { call in
                OpenAIChatRequest.RequestToolCall(
                    id: call.id,
                    function: .init(
                        name: call.function.name,
                        arguments: call.function.arguments
                    )
                )
            }

        return OpenAIChatRequest.RequestMessage(
            role: message.role.rawValue,
            content: message.content,
            toolCalls: toolCalls,
            toolCallID: message.toolCallID
        )
    }

    /// Converts a public ``Tool`` to the internal request representation.
    private func convertTool(
        _ tool: any Tool
    ) -> OpenAIChatRequest.RequestTool {
        OpenAIChatRequest.RequestTool(
            function: .init(
                name: tool.name,
                description: tool.description,
                parameters: tool.parametersSchema
            )
        )
    }

    // MARK: - Response Conversion

    /// Converts an internal API response to the public ``ChatResponse``.
    private func convertResponse(
        _ response: OpenAIChatResponse
    ) throws(AgentKitError) -> ChatResponse {
        guard let choice = response.choices.first else {
            throw .providerError("No choices in response")
        }

        let toolCalls = (choice.message.toolCalls ?? []).map { tc in
            ToolCall(
                id: tc.id,
                function: .init(
                    name: tc.function.name,
                    arguments: tc.function.arguments
                )
            )
        }

        let message = Message.assistant(
            choice.message.content,
            reasoningContent: choice.message.reasoningContent ?? choice.message.reasoning,
            toolCalls: toolCalls
        )

        let finishReason = mapFinishReason(choice.finishReason)

        let usage = response.usage.map { u in
            ChatResponse.Usage(
                promptTokens: u.promptTokens,
                completionTokens: u.completionTokens,
                totalTokens: u.totalTokens
            )
        }

        return ChatResponse(
            message: message,
            finishReason: finishReason,
            usage: usage
        )
    }

    /// Converts an internal streaming chunk to a public ``ChatStreamDelta``.
    private func convertStreamResponse(
        _ response: OpenAIStreamResponse
    ) -> ChatStreamDelta {
        guard let choice = response.choices.first else {
            return ChatStreamDelta()
        }

        let toolCallDeltas: [ChatStreamDelta.ToolCallDelta]? =
            choice.delta.toolCalls?.map { tc in
                ChatStreamDelta.ToolCallDelta(
                    index: tc.index,
                    id: tc.id,
                    functionName: tc.function?.name,
                    argumentsDelta: tc.function?.arguments
                )
            }

        let finishReason = choice.finishReason.flatMap { raw in
            mapFinishReason(raw)
        }

        return ChatStreamDelta(
            deltaContent: choice.delta.content,
            deltaReasoningContent: choice.delta.reasoningContent ?? choice.delta.reasoning,
            deltaToolCalls: toolCallDeltas,
            finishReason: finishReason
        )
    }

    // MARK: - Helpers

    /// Maps the raw finish-reason string to the typed enum.
    private func mapFinishReason(
        _ raw: String?
    ) -> ChatResponse.FinishReason {
        guard let raw else { return .stop }
        return ChatResponse.FinishReason(rawValue: raw) ?? .stop
    }
}
