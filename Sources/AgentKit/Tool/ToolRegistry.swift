// ToolRegistry.swift
// AgentKit
//

import Foundation

/// A thread-safe registry that manages a collection of tools available to an agent.
///
/// `ToolRegistry` uses Swift's actor isolation to guarantee safe concurrent
/// access when tools are registered, looked up, or removed.
///
/// ```swift
/// let registry = ToolRegistry(tools: [myTool])
/// await registry.register(anotherTool)
/// let tool = await registry.tool(named: "get_weather")
/// ```
public actor ToolRegistry {

    // MARK: - Storage

    private var tools: [String: any Tool]

    // MARK: - Init

    /// Creates a new registry, optionally pre-populated with the given tools.
    ///
    /// - Parameter tools: An array of tools to register immediately.
    ///   If multiple tools share the same name, the last one wins.
    public init(tools: [any Tool] = []) {
        var store: [String: any Tool] = [:]
        store.reserveCapacity(tools.count)
        for tool in tools {
            store[tool.name] = tool
        }
        self.tools = store
    }

    // MARK: - Registration

    /// Registers a single tool.
    ///
    /// If a tool with the same ``Tool/name`` already exists it is replaced.
    ///
    /// - Parameter tool: The tool to register.
    public func register(_ tool: any Tool) {
        tools[tool.name] = tool
    }

    /// Registers multiple tools at once.
    ///
    /// If any tools share the same ``Tool/name``, the last occurrence wins.
    ///
    /// - Parameter tools: The tools to register.
    public func register(contentsOf newTools: [any Tool]) {
        for tool in newTools {
            tools[tool.name] = tool
        }
    }

    // MARK: - Lookup

    /// Returns the tool registered under the given name, or `nil` if none exists.
    ///
    /// - Parameter name: The unique tool name to look up.
    /// - Returns: The matching tool, or `nil`.
    public func tool(named name: String) -> (any Tool)? {
        tools[name]
    }

    /// All currently registered tools, in no particular order.
    public var allTools: [any Tool] {
        Array(tools.values)
    }

    /// The number of tools currently registered.
    public var count: Int {
        tools.count
    }

    // MARK: - Removal

    /// Removes the tool registered under the given name, if any.
    ///
    /// - Parameter name: The name of the tool to remove.
    public func unregister(named name: String) {
        tools.removeValue(forKey: name)
    }
}
