// MCPTool.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// A tool that bridges execution requests to an external Model Context Protocol (MCP) server.
///
/// When called, `MCPTool` serializes the argument input and relays it to the MCP Server
/// via standard JSON-RPC `tools/call` procedures.
public struct MCPTool: Tool {

    // MARK: - Properties

    public let name: String
    public let description: String
    public let parametersSchema: JSONValue
    private let client: MCPClient

    // MARK: - Initialization

    /// Creates a new MCP-backed tool.
    ///
    /// - Parameters:
    ///   - name: Unique tool name.
    ///   - description: Human-readable description.
    ///   - parametersSchema: Parameter schema definition.
    ///   - client: The MCP client managing the server lifecycle.
    public init(
        name: String,
        description: String,
        parametersSchema: JSONValue,
        client: MCPClient
    ) {
        self.name = name
        self.description = description
        self.parametersSchema = parametersSchema
        self.client = client
    }

    // MARK: - Tool Conformance

    public func call(arguments: String) async throws(AgentKitError) -> String {
        // Decode raw arguments into dynamic JSONValue
        let parsedArgs: JSONValue
        do {
            parsedArgs = try JSONValue.decodeFromString(JSONValue.self, from: arguments)
        } catch {
            throw .encodingError("Failed to parse MCP arguments for '\(name)': \(error)")
        }

        // Standard MCP tools/call payload structure: { "name": "...", "arguments": { ... } }
        let params = JSONValue.object([
            "name": .string(name),
            "arguments": parsedArgs
        ])

        do {
            let response = try await client.sendRequest(method: "tools/call", params: params)
            
            guard case .object(let dict) = response else {
                throw AgentKitError.providerError("Invalid response format from MCP Server")
            }

            // Check if isError is set to true
            if let isErrorVal = dict["isError"], case .bool(let isError) = isErrorVal, isError {
                let errorMsg = extractTextContent(from: dict) ?? "Unknown MCP error"
                throw AgentKitError.toolExecutionFailed(toolName: name, reason: errorMsg)
            }

            guard let textResult = extractTextContent(from: dict) else {
                throw AgentKitError.providerError("MCP Tool returned empty content")
            }

            return textResult
        } catch let error as AgentKitError {
            throw error
        } catch {
            throw AgentKitError.toolExecutionFailed(toolName: name, reason: error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    private func extractTextContent(from dict: [String: JSONValue]) -> String? {
        guard let contentVal = dict["content"], case .array(let contentArray) = contentVal else {
            return nil
        }

        var textParts: [String] = []
        for contentItem in contentArray {
            if case .object(let itemDict) = contentItem,
               let typeVal = itemDict["type"], case .string("text") = typeVal,
               let textVal = itemDict["text"], case .string(let text) = textVal {
                textParts.append(text)
            }
        }

        return textParts.isEmpty ? nil : textParts.joined(separator: "\n")
    }
}
