# AgentKit.swift AI Coding Rules

You are an expert iOS/macOS developer. The user is using **AgentKit.swift**, an AI-Native, Protocol-First Agent Framework, to build AI features in their app. When generating code that uses AgentKit, you MUST follow these rules:

## 1. Core Concepts
- AgentKit is built on Swift 6 strict concurrency (`Sendable`, `actor`).
- **Do not** instantiate `Agent` directly using `init`. You **MUST** use `AgentBuilder`.
- Provider configuration must be passed during the builder chain.

## 2. API Keys and Security
- **Never** hardcode API keys in the source code.
- Assume the user is using `KeychainStore` from AgentKit to retrieve keys, or injecting them securely.
- To encrypt or sign requests, inject `RequestInterceptor` instances into the `ProviderConfiguration`.

## 3. Creating an Agent
Always use `AgentBuilder`. Here is the exact pattern you must follow:

```swift
import AgentKit

let keychain = KeychainStore()
let apiKey = keychain.retrieve(forAccount: "openai") ?? ""

let agent = try AgentBuilder()
    .provider(
        OpenAIChatProvider(), 
        configuration: ProviderConfiguration(apiKey: apiKey) // Add interceptors: [...] here if needed
    )
    .skill(weatherSkill) // Use .skill() to inject grouped tools and system prompts
    .build()
```

## 4. Multi-Provider Support
AgentKit supports multiple providers. When the user asks for a specific model, use the correct provider:
- **OpenAI**: `OpenAIChatProvider()`
- **Claude**: `ClaudeChatProvider()`
- **Apple On-Device (iOS 26+)**: `FoundationModelsChatProvider()` with `ProviderConfiguration.onDevice()`
- **DeepSeek/Ollama**: Use `OpenAICompatibleProvider.deepSeek(apiKey: ...)` or `.ollama(baseURL: ...)`

## 5. Streaming Responses
Always use `agent.run(prompt)` which returns an `AsyncThrowingStream<AgentEvent, Error>`. 
You must iterate over the stream to get `streamDelta` and handle the events:

```swift
let session = Session(systemPrompt: "You are a helpful assistant")
let events = await agent.run("Hello!", session: session)

for try await event in events {
    switch event {
    case .streamReasoningDelta(let text):
        // Append thinking process to UI (e.g., DeepSeek R1)
    case .streamDelta(let text):
        // Append text to UI
    case .toolCallStarted(let toolCall):
        // Handle tool UI state
    case .toolCallCompleted(_, let result):
        // Handle tool completion
    case .error(let error):
        // Handle error
    case .completed:
        // Stream finished
    default:
        break
    }
}
```

## 6. Defining Tools
Tools must conform to the JSON Schema specification. Prefer using `FunctionTool`:

```swift
let myTool = FunctionTool(
    name: "get_data",
    description: "Fetches data.",
    parametersSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "query": .object(["type": .string("string")])
        ]),
        "required": .array([.string("query")])
    ])
) { args in
    return "Result for \(args)"
}
```

## 7. Using the Planner
If the user wants to execute a multi-step complex task, wrap the agent in a `Planner`:

```swift
let planner = Planner(agent: agent)
let events = await planner.execute(goal: "Your complex goal")
// iterate over events handling .planGenerated, .stepStarted, .stepCompleted
```

## 8. State & Memory Management
Always use `Session` to manage multi-turn conversations. `Session` is an actor and thread-safe. Pass the session into `agent.run(prompt, session: session)` to ensure the agent remembers context.
