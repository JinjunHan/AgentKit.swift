# AgentKit.swift

[English](README.md) | [简体中文](README_zh.md)

AgentKit.swift is an AI-Native, Protocol-First Agent Framework for iOS 18+ and macOS 15+ (macOS 26 ready). Designed from the ground up for Swift's modern concurrency model, it makes building tool-using AI agents simple, type-safe, and robust.

## Features

- **Swift-First**: Fully utilizes Swift 6 strict concurrency (`Sendable`, Actors).
- **AI-First**: Built for agentic workflows (Looping, Tool Calling, Streaming).
- **Multi-Provider Ecosystem**: Support for **Apple Foundation Models** (on-device iOS 26+), **OpenAI**, **Claude**, and an adapter for OpenAI-compatible endpoints (**DeepSeek**, **Ollama**, **Groq**, **Together AI**).
- **Planner Module**: Automatically decompose complex goals into multi-step execution plans with self-correction capabilities.
- **API Security Suite**: Pluggable interceptor chain with built-in:
  - **HMAC-SHA256** request signing (anti-replay)
  - **AES-GCM** body encryption
  - **TLS Certificate Pinning** (anti-MITM)
  - **iOS Keychain** secure key storage
- **Protocol-First**: Easily plug in custom models, interceptors, and tools.
- **SSE Streaming**: Built-in Server-Sent Events parser utilizing `URLSession.AsyncBytes`, ensuring zero external dependencies.
- **Builder DSL**: Construct agents cleanly using a builder pattern.

---

## Installation

### Swift Package Manager (SPM)

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/JinjunHan/AgentKit.swift.git", from: "0.1.0")
]
```

Or add it directly in Xcode: `File -> Add Packages...` and enter the repository URL.

---

## Quick Start

> **Security Note**: Storing third-party API keys (like OpenAI) directly in client applications is discouraged for production. The provided security interceptors (HMAC, AES, TLS Pinning) are designed to secure the connection between your iOS app and your own Backend-For-Frontend (BFF) server.

### 1. Build an Agent

Configure the LLM Provider and build your agent using the chainable `AgentBuilder`:

```swift
import AgentKit

// Configure Cryptographic Interceptors for your BFF (Optional)
let signer = HMACSigner(secretKeyString: "my-shared-secret")

let agent = try AgentBuilder()
    .provider(
        OpenAIChatProvider(),
        configuration: ProviderConfiguration(
            apiKey: "your-api-key", // In production, use your own backend token
            interceptors: [signer]  // Interceptors applied automatically
        )
    )
    .systemPrompt("You are a helpful assistant.")
    .build()
```

### 2. Basic Interactive Chat

You can seamlessly chat with your agent. AgentKit streams responses and tool-call events in real-time natively using Swift `AsyncSequence`:

```swift
let events = await agent.run("What is the weather in Tokyo?")

for try await event in events {
    switch event {
    case .streamDelta(let text):
        print(text, terminator: "") // Real-time streaming
    case .toolCallStarted(let tool):
        print("\n🔧 Using tool: \(tool.function.name)")
    case .messageCompleted(let message):
        print("\n✅ Final Response: \(message.content ?? "")")
    case .error(let error):
        print("\n❌ Error: \(error)")
    default:
        break
    }
}
```

### 3. Multi-Step Execution with Planner

Use the Planner module to decompose complex goals and execute them sequentially:

```swift
import AgentKit

let planner = Planner(agent: agent)
let events = await planner.execute(goal: "Write a python script to scrape news, then save it to a file.")

for try await event in events {
    switch event {
    case .planGenerated(let plan):
        print("Generated \(plan.steps.count) steps.")
    case .stepStarted(let step):
        print("Executing: \(step.description)")
    case .stepCompleted(let step, let result):
        print("✅ \(step.description) -> \(result)")
    case .completed(let plan):
        print("Goal finished! \(plan.progressDescription)")
    default:
        break
    }
}
```

### 4. Injecting Tools and Skills

You can easily equip your agent with custom capabilities by conforming to the `Tool` protocol, and optionally grouping them into reusable `Skill` containers:

```swift
struct WeatherTool: Tool {
    let name = "get_weather"
    let description = "Get current weather for a city."
    let parametersSchema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "city": .object(["type": .string("string")])
        ]),
        "required": .array([.string("city")])
    ])

    func call(arguments: String) async throws(AgentKitError) -> String {
        return "It's sunny in Tokyo!" // Implement your logic here
    }
}

// Group instructions and tools into a reusable Skill
let weatherSkill = Skill(
    name: "Meteorologist",
    description: "Allows the agent to check the weather.",
    systemPrompt: "You are a friendly meteorologist. Always use emojis.",
    tools: [WeatherTool()]
)

let agent = try AgentBuilder()
    .provider(OpenAIChatProvider(), configuration: ProviderConfiguration(apiKey: "your-api-key"))
    .skill(weatherSkill)
    // .tools([WeatherTool()]) // Or inject tools directly
    .build()
```

### 5. State & Memory Management

AgentKit manages conversation history and contextual memory through the thread-safe `Session` actor, providing multi-layered memory scopes (Working, Session, User, Semantic):

```swift
let session = Session(systemPrompt: "You are a helpful assistant.")

// 1. Working Memory (Ephemeral Key-Value)
await session.memory.setWorkingMemory(key: "user_name", value: "Alice")

// 2. User Memory (Long-term facts)
try await session.memory.saveUserMemory("User is allergic to peanuts.")

// Run agent using the stateful session
let agent = try AgentBuilder()
    .provider(OpenAIChatProvider())
    .session(session) // Inject session state
    .build()

let events = await agent.run("What should I eat?")
```

---

## Architecture

AgentKit.swift consists of the following core modules:

- **Agent**: The main entry point orchestrating the run loop.
- **Planner**: Actor for multi-step goal decomposition and automated execution.
- **Session**: Manages conversation history state safely inside an `actor`.
- **Security**: Pluggable `RequestInterceptor` chain, `HMACSigner`, `AESEncryptor`, `CertificatePinner`, and `KeychainStore`.
- **Tool / ToolRegistry**: Define tools using JSON Schema parameters and invoke them dynamically.
- **ChatProvider**: Plug in different LLMs (`OpenAIChatProvider`, `ClaudeChatProvider`, `FoundationModelsChatProvider`).

---

## For AI Assistants (Cursor / Copilot / Windsurf)

If you are using an AI coding assistant to build your app with AgentKit, you can teach it how to use this framework perfectly:

1. Copy the [`AgentKit-CursorRules-Template.md`](AgentKit-CursorRules-Template.md) file from this repository.
2. Paste its contents into your project's `.cursorrules` or `.windsurfrules` file at your workspace root.
3. Alternatively, type `@AgentKit-CursorRules-Template.md` in your AI chat to add it to the context.

This will ensure your AI generates Swift 6 strict-concurrency compliant code, uses the `AgentBuilder` correctly, and implements streaming securely.

---

## Examples

To run the built-in CLI example, set your `OPENAI_API_KEY` and run:

```bash
export OPENAI_API_KEY="sk-..."
swift run AgentKitExample
```

## License

MIT License. See [LICENSE](LICENSE) for details.