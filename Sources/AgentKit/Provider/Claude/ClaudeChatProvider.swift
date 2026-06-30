// ClaudeChatProvider.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// A ``ChatProvider`` implementation that communicates with the Anthropic Claude Messages API.
///
/// Supports both blocking (``sendChat(messages:tools:configuration:)``) and
/// streaming (``streamChat(messages:tools:configuration:)``) interactions.
///
/// ```swift
/// let provider = ClaudeChatProvider()
/// let response = try await provider.sendChat(
///     messages: [.user("Hello!")],
///     tools: [],
///     configuration: ProviderConfiguration(apiKey: "sk-ant-...", model: "claude-3-5-sonnet-20240620")
/// )
/// ```
public struct ClaudeChatProvider: ChatProvider {

    // MARK: - Properties

    private let session: URLSession

    // MARK: - Init

    /// Creates a new Claude chat provider.
    ///
    /// - Parameter session: The `URLSession` to use for network requests.
    ///   Defaults to `.shared`.
    public init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - ChatProvider Conformance

    public func sendChat(
        messages: [Message],
        tools: [any Tool],
        configuration: ProviderConfiguration
    ) async throws(AgentKitError) -> ChatResponse {
        let body = try buildRequest(
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
            throw AgentKitError.providerError(error.localizedDescription)
        }

        let data: Data
        let httpResponse: HTTPURLResponse
        do {
            let (responseData, response) = try await session.data(for: urlRequest)
            data = responseData
            guard let resp = response as? HTTPURLResponse else {
                throw AgentKitError.networkError("Invalid HTTP response type")
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
                ClaudeErrorResponse.self, from: data
            ) {
                throw .providerError(apiError.error.message)
            }
            throw .providerError("HTTP \(httpResponse.statusCode)")
        }

        let decoded: ClaudeMessageResponse
        do {
            decoded = try JSONDecoder().decode(
                ClaudeMessageResponse.self,
                from: data
            )
        } catch {
            throw .encodingError("Failed to decode Claude response: \(error.localizedDescription)")
        }

        return try convertResponse(decoded)
    }

    public func streamChat(
        messages: [Message],
        tools: [any Tool],
        configuration: ProviderConfiguration
    ) -> AsyncThrowingStream<ChatStreamDelta, any Error> {
        let body: ClaudeMessageRequest
        do {
            body = try buildRequest(
                messages: messages,
                tools: tools,
                configuration: configuration,
                stream: true
            )
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }

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
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                        }
                        if let apiError = try? JSONDecoder().decode(
                            ClaudeErrorResponse.self,
                            from: Data(errorBody.utf8)
                        ) {
                            continuation.finish(throwing: AgentKitError.providerError(apiError.error.message))
                        } else {
                            continuation.finish(throwing: AgentKitError.providerError("HTTP \(httpResponse.statusCode)"))
                        }
                        return
                    }

                    var activeToolCallIndex = 0
                    for try await response in SSEParser.events(
                        from: bytes,
                        decodingType: ClaudeStreamResponse.self
                    ) {
                        if let delta = convertStreamResponse(response, activeToolCallIndex: &activeToolCallIndex) {
                            continuation.yield(delta)
                        }
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

    private func buildRequest(
        messages: [Message],
        tools: [any Tool],
        configuration: ProviderConfiguration,
        stream: Bool
    ) throws(AgentKitError) -> ClaudeMessageRequest {
        // Collect system prompts from the core messages list
        let systemPromptParts = messages
            .filter { $0.role == .system }
            .compactMap { $0.content }
        let systemPrompt = systemPromptParts.isEmpty ? nil : systemPromptParts.joined(separator: "\n\n")

        // Map rest of the messages to ClaudeMessage format (system prompts excluded)
        let claudeMessages = messages
            .filter { $0.role != .system }
            .map { convertMessage($0) }

        let claudeTools = tools.isEmpty ? nil : tools.map { convertTool($0) }

        // Use custom model if provided, otherwise default to sonnet 3.5
        let model = configuration.model.isEmpty ? "claude-3-5-sonnet-20240620" : configuration.model
        let maxTokens = configuration.maxTokens ?? 4096

        return ClaudeMessageRequest(
            model: model,
            system: systemPrompt,
            messages: claudeMessages,
            tools: claudeTools,
            maxTokens: maxTokens,
            temperature: configuration.temperature,
            stream: stream ? true : nil
        )
    }

    private func makeURLRequest(
        configuration: ProviderConfiguration,
        body: ClaudeMessageRequest
    ) async throws -> URLRequest {
        let baseURL = configuration.baseURL.isEmpty ? "https://api.anthropic.com" : configuration.baseURL
        let urlString = "\(baseURL)/v1/messages"
        
        guard let url = URL(string: urlString) else {
            throw AgentKitError.invalidConfiguration("Invalid base URL: \(baseURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw AgentKitError.encodingError("Failed to encode Claude request: \(error.localizedDescription)")
        }

        // Apply interceptor chain
        if !configuration.interceptors.isEmpty {
            let chain = InterceptorChain(interceptors: configuration.interceptors)
            do {
                request = try await chain.execute(request: request)
            } catch {
                throw AgentKitError.providerError("Interceptor failed: \(error.localizedDescription)")
            }
        }

        return request
    }

    // MARK: - Message Conversion

    private func convertMessage(_ message: Message) -> ClaudeMessage {
        var blocks: [ClaudeContentBlock] = []

        // If text content is present, add text content block
        if let content = message.content, !content.isEmpty {
            blocks.append(.text(content))
        }

        // If tool call requests exist in assistant message, map them
        for tc in message.toolCalls {
            let argumentsJSON: JSONValue
            if let data = tc.function.arguments.data(using: .utf8),
               let json = try? JSONDecoder().decode(JSONValue.self, from: data) {
                argumentsJSON = json
            } else {
                argumentsJSON = .object([:])
            }
            blocks.append(.toolUse(id: tc.id, name: tc.function.name, input: argumentsJSON))
        }

        // If tool result block, append toolResult block
        if message.role == .tool, let callID = message.toolCallID, let content = message.content {
            blocks.append(.toolResult(toolUseID: callID, content: content))
        }

        // Claude only expects "user" or "assistant" roles.
        // Core messages of role .tool are mapped to "user" containing a toolResult block.
        let role = (message.role == .assistant) ? "assistant" : "user"

        return ClaudeMessage(role: role, content: blocks)
    }

    private func convertTool(_ tool: any Tool) -> ClaudeTool {
        // Strip parameters schema root object type to fetch properties if nested
        ClaudeTool(
            name: tool.name,
            description: tool.description,
            inputSchema: tool.parametersSchema
        )
    }

    // MARK: - Response Conversion

    private func convertResponse(
        _ response: ClaudeMessageResponse
    ) throws(AgentKitError) -> ChatResponse {
        var textContent = ""
        var toolCalls: [ToolCall] = []

        for block in response.content {
            if block.type == "text", let text = block.text {
                textContent += text
            } else if block.type == "tool_use", let id = block.id, let name = block.name, let input = block.input {
                let argumentsString = input.description
                toolCalls.append(
                    ToolCall(
                        id: id,
                        function: .init(name: name, arguments: argumentsString)
                    )
                )
            }
        }

        let content = textContent.isEmpty ? nil : textContent
        let message = Message.assistant(content, toolCalls: toolCalls)

        let stopReason: ChatResponse.FinishReason
        switch response.stopReason {
        case "tool_use":
            stopReason = .toolCalls
        case "max_tokens":
            stopReason = .length
        default:
            stopReason = .stop
        }

        let usage = response.usage.map { u in
            ChatResponse.Usage(
                promptTokens: u.inputTokens,
                completionTokens: u.outputTokens,
                totalTokens: u.inputTokens + u.outputTokens
            )
        }

        return ChatResponse(
            message: message,
            finishReason: stopReason,
            usage: usage
        )
    }

    private func convertStreamResponse(
        _ response: ClaudeStreamResponse,
        activeToolCallIndex: inout Int
    ) -> ChatStreamDelta? {
        switch response.type {
        case "content_block_start":
            guard let block = response.contentBlock,
                  block.type == "tool_use",
                  let id = block.id,
                  let name = block.name,
                  let index = response.index
            else {
                return nil
            }
            activeToolCallIndex = index
            return ChatStreamDelta(
                deltaToolCalls: [
                    .init(index: index, id: id, functionName: name, argumentsDelta: "")
                ]
            )

        case "content_block_delta":
            guard let delta = response.delta, let index = response.index else {
                return nil
            }
            if delta.type == "text_delta", let text = delta.text {
                return ChatStreamDelta(deltaContent: text)
            } else if delta.type == "input_json_delta", let partial = delta.partialJson {
                return ChatStreamDelta(
                    deltaToolCalls: [
                        .init(index: index, argumentsDelta: partial)
                    ]
                )
            }
            return nil

        case "message_delta":
            guard let delta = response.delta else { return nil }
            let finishReason: ChatResponse.FinishReason?
            switch delta.stopReason {
            case "tool_use":
                finishReason = .toolCalls
            case "max_tokens":
                finishReason = .length
            case "end_turn":
                finishReason = .stop
            default:
                finishReason = nil
            }
            return ChatStreamDelta(finishReason: finishReason)

        default:
            return nil
        }
    }
}
