// Tool.swift
// AgentKit
//

import Foundation

/// A tool that an Agent can invoke during execution.
///
/// Conform to this protocol to expose custom functionality to an LLM-powered agent.
/// The agent uses ``name`` and ``description`` to decide when to call the tool,
/// and ``parametersSchema`` to construct well-formed arguments.
///
/// ## Example
/// ```swift
/// struct WeatherTool: Tool {
///     let name = "get_weather"
///     let description = "Get current weather for a city."
///     let parametersSchema: JSONValue = .object([
///         "type": .string("object"),
///         "properties": .object([
///             "city": .object(["type": .string("string")])
///         ]),
///         "required": .array([.string("city")])
///     ])
///
///     func call(arguments: String) async throws(AgentKitError) -> String {
///         // Parse arguments and return weather data
///     }
/// }
/// ```
public protocol Tool: Sendable {
    /// Unique name for this tool, used by the LLM to reference it.
    ///
    /// Must be a valid function-name string (alphanumerics and underscores).
    var name: String { get }

    /// Human-readable description of what this tool does.
    ///
    /// The LLM reads this description to decide whether the tool is relevant
    /// for a given user request.
    var description: String { get }

    /// JSON Schema describing the parameters this tool accepts.
    ///
    /// Must be a valid JSON Schema object encoded as ``JSONValue``.
    var parametersSchema: JSONValue { get }

    /// Execute this tool with the given JSON arguments string.
    ///
    /// - Parameter arguments: Raw JSON string of arguments from the LLM.
    /// - Returns: A string result to feed back to the LLM as tool output.
    /// - Throws: ``AgentKitError`` if execution fails.
    func call(arguments: String) async throws(AgentKitError) -> String
}
