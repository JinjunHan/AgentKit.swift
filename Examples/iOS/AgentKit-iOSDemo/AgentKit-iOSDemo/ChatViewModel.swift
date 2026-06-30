// ChatViewModel.swift
// AgentKit-iOSDemo
//
// SPDX-License-Identifier: MIT

import SwiftUI
import Combine
import AgentKit

/// The supported LLM provider types for the demo app.
public enum ProviderType: String, CaseIterable, Identifiable, Sendable {
    case openAI = "OpenAI"
    case claude = "Claude"
    case appleOnDevice = "Apple On-Device"
    case deepSeek = "DeepSeek"
    case openRouter = "OpenRouter"
    case custom = "Custom"

    public var id: String { rawValue }

    /// Whether this provider requires an API key.
    public var requiresAPIKey: Bool {
        switch self {
        case .appleOnDevice:
            return false
        case .openAI, .claude, .deepSeek, .openRouter, .custom:
            return true
        }
    }

    /// Default model for each provider.
    public var defaultModel: String {
        switch self {
        case .openAI: return "gpt-5.5"
        case .claude: return "claude-sonnet-4.6"
        case .appleOnDevice: return "apple-on-device"
        case .deepSeek: return "deepseek-v4-flash"
        case .openRouter: return "openrouter/free"
        case .custom: return ""
        }
    }

    /// Available models for this provider.
    public var availableModels: [String] {
        switch self {
        case .openAI:
            return ["gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna", "gpt-5.4", "gpt-4o"]
        case .claude:
            return ["claude-fable-5", "claude-opus-4.8", "claude-sonnet-4.6"]
        case .appleOnDevice:
            return ["apple-on-device"]
        case .deepSeek:
            return ["deepseek-v4-flash", "deepseek-v4-pro", "deepseek-chat"]
        case .openRouter:
            return ["openrouter/free", "meta-llama/llama-3-70b-instruct", "google/gemini-pro"]
        case .custom:
            return []
        }
    }
}

/// The protocol used by custom endpoints
public enum CustomProtocolType: String, CaseIterable, Identifiable, Sendable {
    case openAIChatCompletions = "OpenAI Chat Completions"
    case anthropicMessages = "Anthropic Messages"
    case openAIResponses = "OpenAI Responses"

    public var id: String { rawValue }
}

/// Manages the state of the chat screen and interacts with the AgentKit SDK.
@MainActor
public final class ChatViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published public var messages: [Message] = []
    @Published public var inputMessage: String = ""
    @Published public var isGenerating: Bool = false
    @Published public var activeToolCall: ToolCall?
    @Published public var errorMessage: String?

    // Provider Selection
    @AppStorage("agentkit_provider") public var selectedProvider: ProviderType = .openAI

    // Config (can be updated via Settings)
    @AppStorage("agentkit_api_key") public var apiKey: String = ""
    @AppStorage("agentkit_anthropic_key") public var anthropicAPIKey: String = ""
    @AppStorage("agentkit_deepseek_key") public var deepSeekAPIKey: String = ""
    @AppStorage("agentkit_openrouter_key") public var openRouterAPIKey: String = ""
    
    @Published public var successMessage: String?
    
    // Custom Provider State
    @AppStorage("agentkit_custom_url") public var customBaseURL: String = ""
    @AppStorage("agentkit_custom_key") public var customAPIKey: String = ""
    @AppStorage("agentkit_custom_protocol") public var customProtocol: CustomProtocolType = .openAIChatCompletions
    @AppStorage("agentkit_custom_model") public var customModel: String = "my-custom-model"

    @Published public var selectedModel: String = "gpt-5.5"
    @Published public var systemPrompt: String = "You are a helpful assistant. Use get_weather when asked about weather."
    @Published public var streamingEnabled: Bool = true
    @Published public var tracingEnabled: Bool = true
    
    @Published public var fetchedModels: [String] = []
    
    @Published public var isFetchingModels: Bool = false
    @Published public var isTestingConnection: Bool = false

    // MARK: - Private Properties

    private var activeAgent: Agent?
    private var tracingPlugin: TracingPlugin?
    
    /// The persistent memory store to maintain conversation history across agent rebuilds.
    private let memoryStore = InMemoryMemoryStore()
    
    /// A custom URLSession that routes through our NetworkLoggerProtocol for robust debugging.
    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [NetworkLoggerProtocol.self] + (config.protocolClasses ?? [])
        return URLSession(configuration: config)
    }()

    // MARK: - Initialization

    public init() {
        if selectedProvider != .custom {
            selectedModel = selectedProvider.defaultModel
        }

        // Populate initial welcome messages
        self.messages = [
            .system("System prompt active. Welcome to AgentKit iOS Demo!"),
            .assistant("Hello! I am an AI agent powered by AgentKit. How can I help you today?")
        ]
    }

    // MARK: - Public Actions

    /// Sends the user message and triggers the Agent execution loop.
    public func sendMessage() async {
        let text = inputMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Validate API key requirement
        if selectedProvider.requiresAPIKey {
            let key = apiKeyForSelectedProvider()
            if key.isEmpty {
                errorMessage = "Please enter an API key for \(selectedProvider.rawValue) in Settings."
                return
            }
        }

        inputMessage = ""
        isGenerating = true
        errorMessage = nil

        // Add user message to UI immediately
        let userMsg = Message.user(text)
        messages.append(userMsg)

        // Add placeholder assistant message for streaming if enabled
        if streamingEnabled {
            messages.append(Message.assistant(""))
        }

        do {
            // Create a mock weather tool
            let weatherTool = FunctionTool(
                name: "get_weather",
                description: "Get the current weather for a city.",
                parametersSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "city": .object([
                            "type": .string("string"),
                            "description": .string("The city name")
                        ])
                    ]),
                    "required": .array([.string("city")])
                ])
            ) { arguments in
                struct Args: Decodable { let city: String }
                let city: String
                if let data = arguments.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode(Args.self, from: data) {
                    city = decoded.city
                } else {
                    city = arguments.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                let encodedCity = city.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? city
                guard let url = URL(string: "https://wttr.in/\(encodedCity)?format=3") else {
                    return "Invalid city name."
                }
                
                do {
                    var request = URLRequest(url: url)
                    request.setValue("AgentKit-Demo/1.0", forHTTPHeaderField: "User-Agent")
                    let (data, _) = try await URLSession.shared.data(for: request)
                    if let result = String(data: data, encoding: .utf8), !result.isEmpty {
                        return result.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    return "Weather data not available."
                } catch {
                    return "Failed to fetch weather: \(error.localizedDescription)"
                }
            }

            // Build the agent with selected provider
            let (provider, providerConfig) = try buildProvider()

            let tracing = TracingPlugin()
            self.tracingPlugin = tracing

            var builder = AgentBuilder()
                .provider(provider, configuration: providerConfig)
                .systemPrompt(systemPrompt)
                .tool(weatherTool)
                .streaming(streamingEnabled)
                .memoryStore(memoryStore)

            if tracingEnabled {
                builder = builder.plugin(tracing)
            }

            let agent = try builder.build()
            self.activeAgent = agent

            // Run agent
            let events = await agent.run(text)

            for try await event in events {
                switch event {
                case .streamDelta(let delta):
                    updateLastAssistantMessage(with: delta)
                case .streamReasoningDelta(let reasoningDelta):
                    updateLastAssistantReasoning(with: reasoningDelta)
                case .toolCallStarted(let toolCall):
                    activeToolCall = toolCall
                case .toolCallCompleted(let toolCall, let result):
                    activeToolCall = nil
                    messages.append(.system("🔧 Tool [\(toolCall.function.name)] returned: \(result)"))

                    if streamingEnabled {
                        messages.append(Message.assistant(""))
                    }
                case .messageCompleted(let finalMsg):
                    if streamingEnabled {
                        if !messages.isEmpty {
                            messages.removeLast()
                        }
                    }
                    messages.append(finalMsg)
                case .error(let error):
                    errorMessage = error.description
                case .completed:
                    break
                default:
                    break
                }
            }

            // Show tracing report if enabled
            if tracingEnabled {
                let spans = await tracing.getSpans()
                if !spans.isEmpty {
                    let report = formatTracingReport(spans: spans)
                    messages.append(.system(report))
                }
            }

        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
        activeToolCall = nil
    }

    public func testConnection() async {
        let text = "Hello"
        
        // Validate API key requirement
        if selectedProvider.requiresAPIKey {
            let key = apiKeyForSelectedProvider()
            if key.isEmpty {
                errorMessage = "Please enter an API key for \(selectedProvider.rawValue) in Settings."
                return
            }
        }
        
        errorMessage = nil
        successMessage = nil
        isTestingConnection = true
        defer { isTestingConnection = false }
        
        do {
            let (provider, providerConfig) = try buildProvider()
            let agent = try AgentBuilder()
                .provider(provider, configuration: providerConfig)
                .systemPrompt("You are a helpful assistant. Just say 'OK'.")
                .streaming(false)
                .build()
                
            let events = await agent.run(text)
            
            var didComplete = false
            for try await event in events {
                switch event {
                case .messageCompleted:
                    didComplete = true
                case .error(let err):
                    errorMessage = "Test Failed: \(err.description)"
                default:
                    break
                }
            }
            
            if didComplete && errorMessage == nil {
                successMessage = "Successfully connected to \(selectedProvider.rawValue) (\(selectedModel))! API is working."
            }
        } catch {
            errorMessage = "Test Failed: \(error.localizedDescription)"
        }
    }

    /// Clears the message history.
    public func clearChat() {
        messages = [
            .assistant("Chat cleared. How can I help you today?")
        ]
        errorMessage = nil
    }

    /// Fetches the available models from the currently selected provider's `/v1/models` endpoint.
    public func fetchModels() async {
        guard selectedProvider != .appleOnDevice else {
            errorMessage = "Apple On-Device does not support fetching models via network."
            return
        }

        let key = apiKeyForSelectedProvider()
        if selectedProvider.requiresAPIKey, key.isEmpty {
            errorMessage = "Please enter an API key first."
            return
        }

        isFetchingModels = true
        defer { isFetchingModels = false }

        var urlString = ""
        var headers: [String: String] = [:]

        switch selectedProvider {
        case .openAI:
            urlString = "https://api.openai.com/v1/models"
            headers["Authorization"] = "Bearer \(key)"
        case .deepSeek:
            urlString = "https://api.deepseek.com/v1/models"
            headers["Authorization"] = "Bearer \(key)"
        case .openRouter:
            urlString = "https://openrouter.ai/api/v1/models"
            headers["Authorization"] = "Bearer \(key)"
        case .claude:
            urlString = "https://api.anthropic.com/v1/models"
            headers["x-api-key"] = key
            headers["anthropic-version"] = "2023-06-01"
        case .custom:
            let base = customBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            urlString = "\(base)/v1/models"
            if customProtocol == .anthropicMessages {
                headers["x-api-key"] = key
                headers["anthropic-version"] = "2023-06-01"
            } else {
                headers["Authorization"] = "Bearer \(key)"
            }
        case .appleOnDevice:
            return
        }

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid base URL."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (k, v) in headers {
            request.setValue(v, forHTTPHeaderField: k)
        }

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResp = response as? HTTPURLResponse else {
                errorMessage = "Invalid response from server."
                return
            }

            if httpResp.statusCode >= 400 {
                errorMessage = "Failed to fetch models: HTTP \(httpResp.statusCode)"
                return
            }

            // Both OpenAI and Anthropic format: {"data": [{"id": "model-id"}]}
            struct ModelsResponse: Decodable {
                struct ModelData: Decodable {
                    let id: String
                }
                let data: [ModelData]
            }

            let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
            let models = decoded.data.map { $0.id }.sorted()
            
            if models.isEmpty {
                errorMessage = "No models returned by the provider."
            } else {
                self.fetchedModels = models
            }

        } catch {
            errorMessage = "Failed to fetch models: \(error.localizedDescription)"
        }
    }

    // MARK: - Private Helpers

    private func apiKeyForSelectedProvider() -> String {
        switch selectedProvider {
        case .openAI:
            return apiKey
        case .claude:
            return anthropicAPIKey
        case .deepSeek:
            return deepSeekAPIKey
        case .openRouter:
            return openRouterAPIKey
        case .custom:
            return customAPIKey
        case .appleOnDevice:
            return ""
        }
    }

    private func buildProvider() throws(AgentKitError) -> (any ChatProvider, ProviderConfiguration) {
        switch selectedProvider {
        case .openAI:
            return (
                OpenAIChatProvider(session: urlSession),
                ProviderConfiguration(apiKey: apiKey, model: selectedModel)
            )
        case .claude:
            return (
                ClaudeChatProvider(session: urlSession),
                ProviderConfiguration(apiKey: anthropicAPIKey, model: selectedModel)
            )
        case .appleOnDevice:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                return (
                    FoundationModelsChatProvider(),
                    .onDevice()
                )
            } else {
                throw .invalidConfiguration("Apple On-Device provider requires iOS 26+.")
            }
            #else
            throw .invalidConfiguration("Apple On-Device provider is not available on this platform.")
            #endif
        case .deepSeek:
            return (
                OpenAIChatProvider(session: urlSession),
                ProviderConfiguration(apiKey: deepSeekAPIKey, baseURL: "https://api.deepseek.com", model: selectedModel)
            )
        case .openRouter:
            return (
                OpenAIChatProvider(session: urlSession),
                ProviderConfiguration(apiKey: openRouterAPIKey, baseURL: "https://openrouter.ai/api", model: selectedModel)
            )
        case .custom:
            let actualModel = selectedModel == "" ? customModel : selectedModel
            switch customProtocol {
            case .openAIChatCompletions, .openAIResponses:
                return (
                    OpenAIChatProvider(session: urlSession),
                    ProviderConfiguration(apiKey: customAPIKey, baseURL: customBaseURL, model: actualModel)
                )
            case .anthropicMessages:
                return (
                    ClaudeChatProvider(session: urlSession),
                    ProviderConfiguration(apiKey: customAPIKey, baseURL: customBaseURL, model: actualModel)
                )
            }
        }
    }

    private func updateLastAssistantMessage(with delta: String) {
        guard !messages.isEmpty else { return }
        let lastIndex = messages.count - 1
        let lastMsg = messages[lastIndex]

        if lastMsg.role == .assistant {
            let updatedContent = (lastMsg.content ?? "") + delta
            messages[lastIndex] = Message(
                id: lastMsg.id,
                role: .assistant,
                content: updatedContent,
                reasoningContent: lastMsg.reasoningContent,
                toolCalls: lastMsg.toolCalls,
                toolCallID: lastMsg.toolCallID,
                createdAt: lastMsg.createdAt
            )
        }
    }

    private func updateLastAssistantReasoning(with delta: String) {
        guard !messages.isEmpty else { return }
        let lastIndex = messages.count - 1
        let lastMsg = messages[lastIndex]

        if lastMsg.role == .assistant {
            let updatedReasoning = (lastMsg.reasoningContent ?? "") + delta
            messages[lastIndex] = Message(
                id: lastMsg.id,
                role: .assistant,
                content: lastMsg.content,
                reasoningContent: updatedReasoning,
                toolCalls: lastMsg.toolCalls,
                toolCallID: lastMsg.toolCallID,
                createdAt: lastMsg.createdAt
            )
        }
    }

    private func formatTracingReport(spans: [TraceSpan]) -> String {
        var lines = ["📈 Trace Report (\(selectedProvider.rawValue))"]
        lines.append("─────────────────────────")

        let sorted = spans.sorted { $0.startTime < $1.startTime }
        for span in sorted {
            let duration = String(format: "%.2f", span.duration)
            lines.append("├── \(span.name): \(duration)s")
            for (key, val) in span.metadata.sorted(by: { $0.key < $1.key }) {
                lines.append("│    └── \(key): \(val)")
            }
        }
        lines.append("─────────────────────────")
        return lines.joined(separator: "\n")
    }
}
