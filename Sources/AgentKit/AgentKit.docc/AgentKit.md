# ``AgentKit``

An AI-Native, Protocol-First Agent Framework for iOS 18+ and macOS 15+.

## Overview

AgentKit.swift makes building tool-using AI agents simple, type-safe, and robust. It is designed from the ground up to support Swift 6's strict concurrency (`Sendable`, `actor`), providing a modern architecture for integrating LLMs into your Apple ecosystem apps.

### Core Features

- **Protocol-First:** Extensible architecture using ``ChatProvider`` and ``Tool``.
- **Multi-Provider:** Supports OpenAI, Claude, Apple Foundation Models, DeepSeek, and Ollama out of the box.
- **Security Suite:** Built-in HMAC-SHA256 signing, AES-GCM encryption, TLS Pinning, and Keychain storage.
- **Planner Module:** Automatically decomposes complex tasks into execution steps with self-correction capabilities.
- **Server-Sent Events (SSE):** Native streaming using `URLSession.AsyncBytes` with zero external dependencies.

## Topics

### Core Components

- ``Agent``
- ``AgentBuilder``
- ``Planner``
- ``Plan``

### Protocols

- ``ChatProvider``
- ``RequestInterceptor``
- ``Tool``

### Security

- ``HMACSigner``
- ``AESEncryptor``
- ``CertificatePinner``
- ``KeychainStore``
