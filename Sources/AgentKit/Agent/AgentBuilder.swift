// AgentBuilder.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// A chainable builder for constructing an ``Agent`` with a fluent DSL.
///
/// `AgentBuilder` uses value-type semantics — each configuration method
/// returns a new copy with the modified property, leaving the original
/// builder unchanged.
///
/// ## Usage
/// ```swift
/// let agent = try AgentBuilder()
///     .provider(OpenAIChatProvider(), configuration: providerConfig)
///     .systemPrompt("You are a helpful assistant.")
///     .tool(myTool)
///     .build()
/// ```
public struct AgentBuilder: Sendable {

    // MARK: - Properties

    /// The chat provider for model communication.
    private var _provider: (any ChatProvider)?

    /// Configuration for the chat provider.
    private var _providerConfiguration: ProviderConfiguration?

    /// Optional system prompt for the agent.
    private var _systemPrompt: String?

    /// Maximum tool-call loop iterations.
    private var _maxIterations: Int = 10

    /// Whether streaming responses are enabled.
    private var _streamingEnabled: Bool = true

    /// Tools available to the agent.
    private var _tools: [any Tool] = []

    /// Skills configured for the agent.
    private var _skills: [Skill] = []

    /// Pluggable memory store.
    private var _memoryStore: any MemoryStore = InMemoryMemoryStore()

    /// Plugins configured for the agent.
    private var _plugins: [any AgentPlugin] = []
    
    /// Optional semantic tool retriever.
    private var _toolRetriever: (any ToolRetriever)?

    // MARK: - Initialization

    /// Creates a new, empty agent builder.
    public init() {}

    // MARK: - Configuration Methods

    /// Sets the chat provider and its configuration.
    ///
    /// - Parameters:
    ///   - provider: The chat provider for model communication.
    ///   - configuration: The provider's configuration (API key, model, etc.).
    /// - Returns: A new builder with the provider set.
    public func provider(
        _ provider: any ChatProvider,
        configuration: ProviderConfiguration
    ) -> AgentBuilder {
        var copy = self
        copy._provider = provider
        copy._providerConfiguration = configuration
        return copy
    }

    /// Sets the system prompt for the agent.
    ///
    /// - Parameter prompt: The system prompt text.
    /// - Returns: A new builder with the system prompt set.
    public func systemPrompt(_ prompt: String) -> AgentBuilder {
        var copy = self
        copy._systemPrompt = prompt
        return copy
    }

    /// Sets the maximum number of tool-call loop iterations.
    ///
    /// - Parameter count: The iteration limit. Defaults to `10`.
    /// - Returns: A new builder with the max iterations set.
    public func maxIterations(_ count: Int) -> AgentBuilder {
        var copy = self
        copy._maxIterations = count
        return copy
    }

    /// Enables or disables streaming responses.
    ///
    /// - Parameter enabled: Whether streaming is enabled.
    /// - Returns: A new builder with the streaming preference set.
    public func streaming(_ enabled: Bool) -> AgentBuilder {
        var copy = self
        copy._streamingEnabled = enabled
        return copy
    }

    /// Adds a single tool to the agent.
    ///
    /// - Parameter tool: The tool to add.
    /// - Returns: A new builder with the tool appended.
    public func tool(_ tool: any Tool) -> AgentBuilder {
        var copy = self
        copy._tools.append(tool)
        return copy
    }

    /// Adds multiple tools to the agent.
    ///
    /// - Parameter tools: The tools to add.
    /// - Returns: A new builder with the tools appended.
    public func tools(_ tools: [any Tool]) -> AgentBuilder {
        var copy = self
        copy._tools.append(contentsOf: tools)
        return copy
    }

    /// Adds a single skill capability to the agent.
    ///
    /// - Parameter skill: The skill to add.
    /// - Returns: A new builder with the skill appended.
    public func skill(_ skill: Skill) -> AgentBuilder {
        var copy = self
        copy._skills.append(skill)
        return copy
    }

    /// Adds multiple skill capabilities to the agent.
    ///
    /// - Parameter skills: The skills to add.
    /// - Returns: A new builder with the skills appended.
    public func skills(_ skills: [Skill]) -> AgentBuilder {
        var copy = self
        copy._skills.append(contentsOf: skills)
        return copy
    }

    /// Sets the dynamic tool retriever for the agent.
    ///
    /// - Parameter retriever: The tool retriever used for dynamic tool routing.
    /// - Returns: A new builder with the retriever set.
    public func toolRetriever(_ retriever: any ToolRetriever) -> AgentBuilder {
        var copy = self
        copy._toolRetriever = retriever
        return copy
    }

    /// Sets the custom memory store for the agent.
    ///
    /// - Parameter store: The memory storage backend.
    /// - Returns: A new builder with the memory store set.
    public func memoryStore(_ store: any MemoryStore) -> AgentBuilder {
        var copy = self
        copy._memoryStore = store
        return copy
    }

    /// Adds a custom plugin to the agent.
    ///
    /// - Parameter plugin: The plugin to add.
    /// - Returns: A new builder with the plugin appended.
    public func plugin(_ plugin: any AgentPlugin) -> AgentBuilder {
        var copy = self
        copy._plugins.append(plugin)
        return copy
    }

    /// Adds multiple custom plugins to the agent.
    ///
    /// - Parameter plugins: The plugins to add.
    /// - Returns: A new builder with the plugins appended.
    public func plugins(_ plugins: [any AgentPlugin]) -> AgentBuilder {
        var copy = self
        copy._plugins.append(contentsOf: plugins)
        return copy
    }

    // MARK: - Build

    /// Builds the ``Agent`` from the accumulated configuration.
    ///
    /// - Throws: ``AgentKitError/invalidConfiguration(_:)`` if the provider
    ///   or provider configuration is missing.
    /// - Returns: A fully configured ``Agent`` instance.
    public func build() throws(AgentKitError) -> Agent {
        guard let provider = _provider else {
            throw .invalidConfiguration(
                "A ChatProvider is required. Call .provider(_:configuration:) before .build()."
            )
        }

        guard let providerConfiguration = _providerConfiguration else {
            throw .invalidConfiguration(
                "A ProviderConfiguration is required. Call .provider(_:configuration:) before .build()."
            )
        }

        let agentConfiguration = AgentConfiguration(
            systemPrompt: _systemPrompt,
            maxIterations: _maxIterations,
            streamingEnabled: _streamingEnabled,
            skills: _skills,
            memoryStore: _memoryStore,
            plugins: _plugins,
            toolRetriever: _toolRetriever
        )

        return Agent(
            provider: provider,
            providerConfiguration: providerConfiguration,
            configuration: agentConfiguration,
            tools: _tools
        )
    }
}
