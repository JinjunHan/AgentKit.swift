// MCPClient.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

#if os(macOS)
/// A client for Model Context Protocol (MCP) servers communicating over stdio JSON-RPC.
///
/// `MCPClient` connects to external servers, registers their tools, and executes them
/// dynamically.
public actor MCPClient {

    // MARK: - Properties

    private let serverPath: String
    private let serverArgs: [String]
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var requestIDCounter = 1
    private var pendingRequests: [Int: CheckedContinuation<JSONValue, any Error>] = [:]

    // MARK: - Initialization

    /// Creates a new MCP client.
    ///
    /// - Parameters:
    ///   - serverPath: Path to the executable (e.g. node, python or an MCP binary).
    ///   - arguments: Command line arguments to pass to the executable.
    public init(serverPath: String, arguments: [String] = []) {
        self.serverPath = serverPath
        self.serverArgs = arguments
    }

    deinit {
        let processRef = self.process
        if let processRef, processRef.isRunning {
            processRef.terminate()
        }
    }

    // MARK: - Public API

    /// Starts the MCP process and begins reading JSON-RPC responses.
    ///
    /// - Throws: ``AgentKitError`` if the process fails to start.
    public func start() throws(AgentKitError) {
        let process = Process()
        
        if serverPath.hasPrefix("/") || serverPath.hasPrefix(".") {
            process.executableURL = URL(fileURLWithPath: serverPath)
            process.arguments = serverArgs
        } else {
            // Treat as system binary (e.g. "node")
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [serverPath] + serverArgs
        }

        let input = Pipe()
        let output = Pipe()

        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw .invalidConfiguration("Failed to execute MCP server: \(error.localizedDescription)")
        }

        self.process = process
        self.inputPipe = input
        self.outputPipe = output

        let handle = output.fileHandleForReading
        Task {
            do {
                for try await line in handle.bytes.lines {
                    self.handleIncomingLine(line)
                }
            } catch {
                // Stdout stream closed or failed
            }
        }
    }

    /// Sends a JSON-RPC request to the MCP server.
    ///
    /// - Parameters:
    ///   - method: JSON-RPC method name.
    ///   - params: Parameter payload.
    /// - Returns: The JSONValue containing the server result.
    /// - Throws: Any JSON-RPC error or transmission failure.
    public func sendRequest(method: String, params: JSONValue?) async throws -> JSONValue {
        let requestID = requestIDCounter
        requestIDCounter += 1

        let request = MCPRequest(id: requestID, method: method, params: params)
        let jsonString = try JSONValue.encodeToString(request) + "\n"

        guard let inputPipe, let data = jsonString.data(using: .utf8) else {
            throw AgentKitError.networkError("MCP Server is not running or IO is unavailable.")
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<JSONValue, any Error>) in
            self.pendingRequests[requestID] = continuation
            do {
                try inputPipe.fileHandleForWriting.write(contentsOf: data)
            } catch {
                self.pendingRequests.removeValue(forKey: requestID)
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Private Helpers

    private func handleIncomingLine(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }
        
        let decoder = JSONDecoder()
        guard let response = try? decoder.decode(MCPResponse.self, from: data),
              let id = response.id else {
            return
        }

        guard let continuation = pendingRequests.removeValue(forKey: id) else {
            return
        }

        if let error = response.error {
            continuation.resume(throwing: AgentKitError.providerError("MCP JSON-RPC Error (\(error.code)): \(error.message)"))
        } else if let result = response.result {
            continuation.resume(returning: result)
        } else {
            continuation.resume(returning: .null)
        }
    }
}

// MARK: - JSON-RPC Models

private struct MCPRequest: Encodable {
    let jsonrpc = "2.0"
    let id: Int
    let method: String
    let params: JSONValue?
}

private struct MCPResponse: Codable {
    let jsonrpc: String
    let id: Int?
    let result: JSONValue?
    let error: MCPErrorDetail?

    struct MCPErrorDetail: Codable {
        let code: Int
        let message: String
    }
}

#else
/// An iOS stub implementation for ``MCPClient`` because child processes/stdio are unsupported in the sandbox.
public actor MCPClient {
    public init(serverPath: String, arguments: [String] = []) {}
    
    public func start() throws(AgentKitError) {
        throw .invalidConfiguration("MCP Stdio Client is unsupported on iOS due to sandbox restrictions.")
    }

    public func sendRequest(method: String, params: JSONValue?) async throws -> JSONValue {
        throw AgentKitError.invalidConfiguration("MCP Stdio Client is unsupported on iOS.")
    }
}
#endif
