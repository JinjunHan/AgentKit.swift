// AgentBuilderTests.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import XCTest
@testable import AgentKit

final class AgentBuilderTests: XCTestCase {
    
    func testAgentBuilderDefaults() throws {
        let builder = AgentBuilder()
        
        // Assert it throws if no provider is configured
        XCTAssertThrowsError(try builder.build()) { error in
            guard let agentError = error as? AgentKitError,
                  case .invalidConfiguration(let message) = agentError else {
                XCTFail("Expected AgentKitError.invalidConfiguration")
                return
            }
            XCTAssertEqual(message, "A ChatProvider is required. Call .provider(_:configuration:) before .build().")
        }
    }
    
    func testAgentBuilderWithConfiguration() throws {
        let provider = OpenAIChatProvider()
        let config = ProviderConfiguration(apiKey: "test-key", model: "gpt-4-test")
        
        let tool = FunctionTool(
            name: "test_tool",
            description: "A test tool",
            parametersSchema: .object([:]),
            handler: { _ in return "Success" }
        )
        
        let agent = try AgentBuilder()
            .provider(provider, configuration: config)
            .systemPrompt("System prompt test")
            .tool(tool)
            .build()
        
        // At this point we can only verify the builder succeeded
        XCTAssertNotNil(agent)
    }
}
