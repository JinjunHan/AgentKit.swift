// ProviderConfiguration.swift
// AgentKit
//

import Foundation

/// Configuration values passed to a ``ChatProvider`` for each request.
///
/// Contains credentials, model selection, and optional sampling parameters.
///
/// ```swift
/// let config = ProviderConfiguration(
///     apiKey: "sk-...",
///     model: "gpt-4o",
///     temperature: 0.7
/// )
/// ```
public struct ProviderConfiguration: Sendable {

    /// The API key used for authentication with the provider.
    public let apiKey: String

    /// The base URL of the provider API (without trailing slash).
    ///
    /// Defaults to `"https://api.openai.com"`.
    public let baseURL: String

    /// The model identifier to use for chat completions.
    ///
    /// Defaults to `"gpt-4o"`.
    public let model: String

    /// Sampling temperature. Higher values make output more random.
    ///
    /// `nil` lets the provider use its default.
    public let temperature: Double?

    /// Maximum number of tokens to generate in the response.
    ///
    /// `nil` lets the provider use its default.
    public let maxTokens: Int?

    /// Nucleus sampling parameter. Considers tokens with top-p probability mass.
    ///
    /// `nil` lets the provider use its default.
    public let topP: Double?
    
    /// A chain of interceptors applied to outgoing URL requests.
    public let interceptors: [any RequestInterceptor]

    /// Creates a new provider configuration.
    ///
    /// - Parameters:
    ///   - apiKey: API key for authentication.
    ///   - baseURL: Base URL of the provider API. Defaults to `"https://api.openai.com"`.
    ///   - model: Model identifier. Defaults to `"gpt-4o"`.
    ///   - temperature: Sampling temperature. Defaults to `nil`.
    ///   - maxTokens: Maximum tokens to generate. Defaults to `nil`.
    ///   - topP: Nucleus sampling parameter. Defaults to `nil`.
    ///   - interceptors: An array of request interceptors. Defaults to empty.
    public init(
        apiKey: String,
        baseURL: String = "https://api.openai.com",
        model: String = "gpt-4o",
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        interceptors: [any RequestInterceptor] = []
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.interceptors = interceptors
    }
}
