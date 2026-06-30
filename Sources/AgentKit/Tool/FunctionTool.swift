// FunctionTool.swift
// AgentKit
//

import Foundation

/// A convenience tool that wraps a closure, removing the need for a dedicated type.
///
/// Use `FunctionTool` when you want to quickly create a tool from a closure
/// instead of defining a full conforming type.
///
/// ```swift
/// let echo = FunctionTool(
///     name: "echo",
///     description: "Echoes the input back.",
///     parametersSchema: .object([
///         "type": .string("object"),
///         "properties": .object([
///             "text": .object(["type": .string("string")])
///         ]),
///         "required": .array([.string("text")])
///     ])
/// ) { arguments in
///     return arguments
/// }
/// ```
public struct FunctionTool: Tool {

    /// Unique name for this tool, used by the LLM to reference it.
    public let name: String

    /// Human-readable description of what this tool does.
    public let description: String

    /// JSON Schema describing the parameters this tool accepts.
    public let parametersSchema: JSONValue

    /// The closure that performs the actual work.
    private let handler: @Sendable (String) async throws(AgentKitError) -> String

    /// Creates a function-based tool.
    ///
    /// - Parameters:
    ///   - name: Unique identifier for the tool.
    ///   - description: Human-readable explanation of the tool's purpose.
    ///   - parametersSchema: JSON Schema for the expected arguments.
    ///   - handler: The closure invoked when the tool is called.
    public init(
        name: String,
        description: String,
        parametersSchema: JSONValue,
        handler: @escaping @Sendable (String) async throws(AgentKitError) -> String
    ) {
        self.name = name
        self.description = description
        self.parametersSchema = parametersSchema
        self.handler = handler
    }

    /// Execute this tool by invoking the stored handler.
    ///
    /// - Parameter arguments: Raw JSON string of arguments from the LLM.
    /// - Returns: A string result to feed back to the LLM.
    /// - Throws: ``AgentKitError`` if the handler fails.
    public func call(arguments: String) async throws(AgentKitError) -> String {
        try await handler(arguments)
    }
}
