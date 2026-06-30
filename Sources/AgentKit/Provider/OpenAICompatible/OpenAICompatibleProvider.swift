// OpenAICompatibleProvider.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// A convenience wrapper around ``OpenAIChatProvider`` for third-party services
/// that expose an OpenAI-compatible Chat Completion API.
///
/// Many LLM providers (DeepSeek, Ollama, Together AI, Groq, etc.) implement
/// the same request/response format as OpenAI. This type provides ergonomic
/// factory methods to create properly configured provider + configuration pairs.
///
/// ## Usage
/// ```swift
/// // DeepSeek
/// let (provider, config) = OpenAICompatibleProvider.deepSeek(apiKey: "sk-...")
///
/// // Ollama (local)
/// let (provider, config) = OpenAICompatibleProvider.ollama(model: "llama3")
///
/// let agent = try AgentBuilder()
///     .provider(provider, configuration: config)
///     .build()
/// ```
public enum OpenAICompatibleProvider {

    // MARK: - DeepSeek

    /// Creates a provider and configuration for the DeepSeek API.
    ///
    /// - Parameters:
    ///   - apiKey: Your DeepSeek API key.
    ///   - model: The model identifier. Defaults to `"deepseek-chat"`.
    ///   - temperature: Optional sampling temperature.
    ///   - maxTokens: Optional max tokens.
    /// - Returns: A tuple of `(ChatProvider, ProviderConfiguration)`.
    public static func deepSeek(
        apiKey: String,
        model: String = "deepseek-chat",
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) -> (any ChatProvider, ProviderConfiguration) {
        let provider = OpenAIChatProvider()
        let config = ProviderConfiguration(
            apiKey: apiKey,
            baseURL: "https://api.deepseek.com",
            model: model,
            temperature: temperature,
            maxTokens: maxTokens
        )
        return (provider, config)
    }

    // MARK: - Ollama

    /// Creates a provider and configuration for a local Ollama instance.
    ///
    /// - Parameters:
    ///   - baseURL: The Ollama server URL. Defaults to `"http://localhost:11434"`.
    ///   - model: The model identifier. Defaults to `"llama3"`.
    ///   - temperature: Optional sampling temperature.
    ///   - maxTokens: Optional max tokens.
    /// - Returns: A tuple of `(ChatProvider, ProviderConfiguration)`.
    public static func ollama(
        baseURL: String = "http://localhost:11434",
        model: String = "llama3",
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) -> (any ChatProvider, ProviderConfiguration) {
        let provider = OpenAIChatProvider()
        let config = ProviderConfiguration(
            apiKey: "ollama",  // Ollama doesn't require a real API key
            baseURL: baseURL,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens
        )
        return (provider, config)
    }

    // MARK: - Together AI

    /// Creates a provider and configuration for Together AI.
    ///
    /// - Parameters:
    ///   - apiKey: Your Together AI API key.
    ///   - model: The model identifier. Defaults to `"meta-llama/Llama-3-70b-chat-hf"`.
    ///   - temperature: Optional sampling temperature.
    ///   - maxTokens: Optional max tokens.
    /// - Returns: A tuple of `(ChatProvider, ProviderConfiguration)`.
    public static func togetherAI(
        apiKey: String,
        model: String = "meta-llama/Llama-3-70b-chat-hf",
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) -> (any ChatProvider, ProviderConfiguration) {
        let provider = OpenAIChatProvider()
        let config = ProviderConfiguration(
            apiKey: apiKey,
            baseURL: "https://api.together.xyz",
            model: model,
            temperature: temperature,
            maxTokens: maxTokens
        )
        return (provider, config)
    }

    // MARK: - Groq

    /// Creates a provider and configuration for Groq.
    ///
    /// - Parameters:
    ///   - apiKey: Your Groq API key.
    ///   - model: The model identifier. Defaults to `"llama3-70b-8192"`.
    ///   - temperature: Optional sampling temperature.
    ///   - maxTokens: Optional max tokens.
    /// - Returns: A tuple of `(ChatProvider, ProviderConfiguration)`.
    public static func groq(
        apiKey: String,
        model: String = "llama3-70b-8192",
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) -> (any ChatProvider, ProviderConfiguration) {
        let provider = OpenAIChatProvider()
        let config = ProviderConfiguration(
            apiKey: apiKey,
            baseURL: "https://api.groq.com/openai",
            model: model,
            temperature: temperature,
            maxTokens: maxTokens
        )
        return (provider, config)
    }

    // MARK: - Custom

    /// Creates a provider and configuration for any OpenAI-compatible endpoint.
    ///
    /// - Parameters:
    ///   - apiKey: The API key for authentication.
    ///   - baseURL: The base URL of the API (without `/v1/chat/completions`).
    ///   - model: The model identifier.
    ///   - temperature: Optional sampling temperature.
    ///   - maxTokens: Optional max tokens.
    /// - Returns: A tuple of `(ChatProvider, ProviderConfiguration)`.
    public static func custom(
        apiKey: String,
        baseURL: String,
        model: String,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) -> (any ChatProvider, ProviderConfiguration) {
        let provider = OpenAIChatProvider()
        let config = ProviderConfiguration(
            apiKey: apiKey,
            baseURL: baseURL,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens
        )
        return (provider, config)
    }
}
