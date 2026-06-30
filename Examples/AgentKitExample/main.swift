// main.swift
// AgentKitExample
//
// A CLI example demonstrating the AgentKit SDK v1.0 features (Multi-Provider, Tracing, SQLite, and Plugins).
// SPDX-License-Identifier: MIT

import AgentKit
import Foundation

// MARK: - Step 1: Create a Custom Tool

let weatherTool = FunctionTool(
    name: "get_weather",
    description: "Get the current weather for a given city.",
    parametersSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "city": .object([
                "type": .string("string"),
                "description": .string("The city name, e.g., Tokyo")
            ])
        ]),
        "required": .array([.string("city")])
    ])
) { arguments in
    let city = arguments.trimmingCharacters(in: .whitespacesAndNewlines)
    return "The weather in \(city.isEmpty ? "Tokyo" : city) is sunny, 25°C."
}

// MARK: - Step 2: Create a Custom Skill

let poetSkill = Skill(
    name: "Poet Assistant",
    description: "Enables the agent to write high-quality short poems.",
    systemPrompt: "You are a poetic assistant. Always reply with a short, beautiful poem.",
    tools: []
)

// MARK: - Step 3: Define Workflow Steps

struct PromptFormatterStep: WorkflowStep {
    let name = "PromptFormatter"

    func execute(input: JSONValue) async throws -> JSONValue {
        guard case .string(let prompt) = input else {
            throw AgentKitError.invalidConfiguration("Input must be a prompt string")
        }
        let formatted = "Please write a poem about: \(prompt)"
        return .string(formatted)
    }
}

struct AgentExecutorStep: WorkflowStep {
    let name = "AgentExecutor"
    let agent: Agent

    func execute(input: JSONValue) async throws -> JSONValue {
        guard case .string(let prompt) = input else {
            throw AgentKitError.invalidConfiguration("Input must be a prompt string")
        }

        print("\n[Workflow: Running Agent with prompt: \"\(prompt)\"]")
        print("Assistant: ", terminator: "")
        fflush(stdout)

        var finalResponse = ""
        let events = await agent.run(prompt)

        for try await event in events {
            switch event {
            case .streamDelta(let text):
                finalResponse += text
                print(text, terminator: "")
                fflush(stdout)
            case .error(let error):
                print("\n[Error event: \(error)]")
            default:
                break
            }
        }
        print("")

        // Store the final assistant output in session memory
        try await agent.session.memory.saveSessionMemory(finalResponse)
        return .string(finalResponse)
    }
}

// MARK: - Main Execution Flow

@main
struct App {
    static func main() async {
        print("🤖 AgentKit v1.0 CLI Example")
        print("=============================")

        let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        let anthropicKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]

        if openAIKey == nil && anthropicKey == nil {
            print("Error: Please set either OPENAI_API_KEY or ANTHROPIC_API_KEY environment variables to run this example.")
            exit(1)
        }

        let dbPath = "agent_memory_demo.db"

        // Clean up database from previous run to make output reproducible
        try? FileManager.default.removeItem(atPath: dbPath)

        // 1. Run OpenAI Demo if key is present
        if let openAIKey {
            print("\n🟢 Running Agent with OpenAI Provider")
            print("-------------------------------------")
            do {
                let memoryStore = try SQLiteMemoryStore(dbPath: dbPath)
                let tracingPlugin = TracingPlugin()
                let logger = LoggerPlugin(prefix: "[OpenAI]")

                let agent = try AgentBuilder()
                    .provider(
                        OpenAIChatProvider(),
                        configuration: ProviderConfiguration(apiKey: openAIKey, model: "gpt-4o-mini")
                    )
                    .tool(weatherTool)
                    .skill(poetSkill)
                    .memoryStore(memoryStore)
                    .plugin(logger)
                    .plugin(tracingPlugin)
                    .build()

                let workflow = Workflow(
                    name: "Poem Generation Pipeline",
                    steps: [
                        PromptFormatterStep(),
                        AgentExecutorStep(agent: agent)
                    ]
                )

                _ = try await workflow.run(initialInput: .string("Sunny weather in Tokyo"))

                // Print Tracing summary
                await tracingPlugin.printReport()
            } catch {
                print("❌ OpenAI execution failed with error: \(error)")
            }
        }

        // 2. Run Anthropic Claude Demo if key is present
        if let anthropicKey {
            print("\n🟢 Running Agent with Anthropic Claude Provider")
            print("-----------------------------------------------")
            do {
                let memoryStore = try SQLiteMemoryStore(dbPath: dbPath)
                let tracingPlugin = TracingPlugin()
                let logger = LoggerPlugin(prefix: "[Claude]")

                let agent = try AgentBuilder()
                    .provider(
                        ClaudeChatProvider(),
                        configuration: ProviderConfiguration(apiKey: anthropicKey, model: "claude-3-5-sonnet-20240620")
                    )
                    .tool(weatherTool)
                    .skill(poetSkill)
                    .memoryStore(memoryStore)
                    .plugin(logger)
                    .plugin(tracingPlugin)
                    .build()

                let workflow = Workflow(
                    name: "Poem Generation Pipeline",
                    steps: [
                        PromptFormatterStep(),
                        AgentExecutorStep(agent: agent)
                    ]
                )

                _ = try await workflow.run(initialInput: .string("Sunny weather in Tokyo"))

                // Print Tracing summary
                await tracingPlugin.printReport()
            } catch {
                print("❌ Claude execution failed with error: \(error)")
            }
        }

        print("\n✅ Multi-Provider and Tracing verification complete!")
    }
}
