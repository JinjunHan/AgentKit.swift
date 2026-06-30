// Skill.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// A structured container that packages a system prompt instruction prefix,
/// a list of specialized tools, and optional descriptive metadata.
///
/// `Skill` allows modular definition of capabilities that can be dynamically
/// composed onto an `Agent` to extend its functionality.
public struct Skill: Sendable, Identifiable {

    // MARK: - Properties

    /// The unique identifier of this skill.
    public let id: String

    /// The human-readable name of the skill.
    public let name: String

    /// A brief description of what this skill enables the agent to do.
    public let description: String

    /// The instruction prefix to prepend to the agent's system prompt.
    public let systemPrompt: String

    /// The collection of tools associated with this skill.
    public let tools: [any Tool]

    // MARK: - Initialization

    /// Creates a new skill capability.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - name: The human-readable name of the skill.
    ///   - description: Description of the skill's purpose.
    ///   - systemPrompt: Prompt instructions injected into the system prompt.
    ///   - tools: Specialized tools offered by this skill. Defaults to empty.
    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        systemPrompt: String,
        tools: [any Tool] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.systemPrompt = systemPrompt
        self.tools = tools
    }
}
