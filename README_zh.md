# AgentKit.swift

[English](README.md) | [简体中文](README_zh.md)

AgentKit.swift 是一个为 iOS 18+ 和 macOS 15+ (已适配 macOS 26) 打造的 AI 原生、基于协议的 Agent 框架。它从底层完全适配 Swift 现代并发模型，让构建使用工具的 AI 智能体变得简单、类型安全且健壮。

## 特性

- **Swift 原生**: 完全使用 Swift 6 严格并发检查 (`Sendable`, Actors)。
- **AI 原生**: 专为 Agentic 工作流设计（循环规划、工具调用、流式输出）。
- **多模型供应商生态**: 支持 **Apple 基础模型**（端侧运行，iOS 26+）、**OpenAI**、**Claude**，并提供 OpenAI 兼容适配器（支持 **DeepSeek**、**Ollama**、**Groq**、**Together AI**）。
- **规划器模块 (Planner)**: 自动将复杂目标分解为多步执行计划，并具备自我纠错与重规划能力。
- **API 安全套件**: 可插拔的拦截器链，内置提供：
  - **HMAC-SHA256** 请求签名（防重放攻击）
  - **AES-GCM** 请求体加密
  - **TLS 证书固定** (TLS Pinning，防中间人攻击)
  - **iOS Keychain** 安全密钥存储
- **协议驱动**: 轻松接入自定义模型、拦截器和工具。
- **SSE 流式传输**: 内置 Server-Sent Events 解析器，使用 `URLSession.AsyncBytes`，确保**零第三方依赖**。
- **Builder DSL**: 使用链式构建器模式，优雅地构建 Agent。

---

## 安装

### Swift Package Manager (SPM)

在你的 `Package.swift` 中添加以下依赖：

```swift
dependencies: [
    .package(url: "https://github.com/JinjunHan/AgentKit.swift.git", from: "0.1.0")
]
```

或者在 Xcode 中直接添加：`File -> Add Packages...` 然后输入仓库地址。

---

## 快速开始

> **安全最佳实践提示**: 在生产环境中，强烈建议不要将第三方（如 OpenAI）的 API Key 直接硬编码或存储在客户端。本框架提供的安全拦截器（HMAC、AES、TLS Pinning）主要是为了保护 iOS 客户端与**您自己的后端服务器 (BFF)** 之间的通信安全而设计的。

### 1. 构建 Agent

配置 LLM 供应商，然后使用链式调用 `AgentBuilder` 构建 Agent：

```swift
import AgentKit

// 配置发往您自家后端的密码学拦截器 (可选)
let signer = HMACSigner(secretKeyString: "my-shared-secret")

let agent = try AgentBuilder()
    .provider(
        OpenAIChatProvider(),
        configuration: ProviderConfiguration(
            apiKey: "your-backend-token", // 在生产环境中，请使用您自家后端的 Token
            interceptors: [signer] // 自动应用拦截器
        )
    )
    .systemPrompt("你是一个乐于助人的 AI 助手。")
    .build()
```

### 2. 基础交互对话 (Chat)

您可以非常简单地与 Agent 进行对话。AgentKit 会利用 Swift 的 `AsyncSequence` 原生流式返回对话文本和工具调用事件：

```swift
let events = await agent.run("东京今天天气怎么样？")

for try await event in events {
    switch event {
    case .streamDelta(let text):
        print(text, terminator: "") // 实时流式输出
    case .toolCallStarted(let tool):
        print("\n🔧 正在调用工具: \(tool.function.name)")
    case .messageCompleted(let message):
        print("\n✅ 最终回复: \(message.content ?? "")")
    case .error(let error):
        print("\n❌ 发生错误: \(error)")
    default:
        break
    }
}
```

### 3. 使用 Planner 执行多步任务

使用 Planner 模块来分解复杂目标并按顺序执行：

```swift
import AgentKit

let planner = Planner(agent: agent)
let events = await planner.execute(goal: "写一个 Python 脚本来抓取新闻，然后保存到文件。")

for try await event in events {
    switch event {
    case .planGenerated(let plan):
        print("已生成 \(plan.steps.count) 个步骤。")
    case .stepStarted(let step):
        print("正在执行: \(step.description)")
    case .stepCompleted(let step, let result):
        print("✅ \(step.description) -> \(result)")
    case .completed(let plan):
        print("目标完成！ \(plan.progressDescription)")
    default:
        break
    }
}
```

### 4. 注入工具 (Tools) 和 技能 (Skills)

通过实现 `Tool` 协议，您可以轻松赋予 Agent 自定义的能力；您还可以将这些工具与特定的系统提示词（System Prompt）打包成一个可复用的 `Skill`（技能）：

```swift
struct WeatherTool: Tool {
    let name = "get_weather"
    let description = "获取指定城市的天气。"
    let parametersSchema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "city": .object(["type": .string("string")])
        ]),
        "required": .array([.string("city")])
    ])

    func call(arguments: String) async throws(AgentKitError) -> String {
        return "东京今天天气晴朗！" // 在此实现您的业务逻辑
    }
}

// 将提示词和工具打包成一个可复用的 Skill
let weatherSkill = Skill(
    name: "气象专家",
    description: "使 Agent 能够查询天气信息。",
    systemPrompt: "你是一个友好的气象专家。请总是使用 emoji 来回答问题。",
    tools: [WeatherTool()]
)

let agent = try AgentBuilder()
    .provider(OpenAIChatProvider(), configuration: ProviderConfiguration(apiKey: "your-backend-token"))
    .skill(weatherSkill)
    // .tools([WeatherTool()]) // 或者直接注入独立的 Tools
    .build()
```

### 5. 状态与记忆管理 (State & Memory)

AgentKit 通过线程安全的 `Session` Actor 来统一管理对话历史和上下文记忆，内置了多层次的记忆作用域（工作记忆、会话记忆、用户记忆、语义记忆）：

```swift
let session = Session(systemPrompt: "你是一个乐于助人的助手。")

// 1. 工作记忆 (临时的 Key-Value 状态)
await session.memory.setWorkingMemory(key: "user_name", value: "Alice")

// 2. 用户记忆 (长期事实)
try await session.memory.saveUserMemory("用户对花生过敏。")

// 使用携带状态的 session 运行 Agent
let agent = try AgentBuilder()
    .provider(OpenAIChatProvider())
    .session(session) // 注入状态
    .build()

let events = await agent.run("我今晚该吃什么？")
```

---

## 架构

AgentKit.swift 包含以下核心模块：

- **Agent**: 编排 Agent 运行循环的主入口。
- **Planner (规划器)**: 用于多步目标分解和自动执行的 Actor。
- **Session (会话)**: 在 Actor 内部安全管理对话历史状态。
- **Security (安全性)**: 可插拔的 `RequestInterceptor` 拦截器链、`HMACSigner`、`AESEncryptor`、`CertificatePinner` 以及 `KeychainStore`。
- **Tool / ToolRegistry (工具/工具注册表)**: 使用 JSON Schema 定义工具，并动态调用它们。
- **ChatProvider (聊天供应商)**: 接入不同的 LLM (`OpenAIChatProvider`、`ClaudeChatProvider`、`FoundationModelsChatProvider`)。

---

## 给 AI 编程助手的说明 (Cursor / Copilot / Windsurf)

如果你正在使用 AI 编程助手来辅助接入 AgentKit，你可以“教”它如何完美地使用本框架：

1. 从本仓库根目录复制 [`AgentKit-CursorRules-Template.md`](AgentKit-CursorRules-Template.md) 文件。
2. 将该文件的内容粘贴到你项目根目录下的 `.cursorrules` 或 `.windsurfrules` 文件中。
3. 或者直接在你的 AI 聊天窗口中输入 `@AgentKit-CursorRules-Template.md`。

这能确保你的 AI 生成符合 Swift 6 严格并发检查的高质量代码、正确使用 `AgentBuilder` 以及安全地处理流式输出。

---

## 示例

运行内置的 CLI 示例，需要配置你的 `OPENAI_API_KEY`，然后运行：

```bash
export OPENAI_API_KEY="sk-..."
swift run AgentKitExample
```

## 开源协议

MIT License. 详情请参阅 [LICENSE](LICENSE) 文件。
