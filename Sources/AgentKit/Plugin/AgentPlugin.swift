// AgentPlugin.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// A protocol representing a plugin that can hook into the Agent's lifecycle events.
///
/// Implement this protocol to add custom telemetry, audit logging, or event tracking.
public protocol AgentPlugin: Sendable {

    /// A unique identifier for this plugin.
    var id: String { get }

    /// A human-readable name for the plugin.
    var name: String { get }

    /// Callback triggered whenever the Agent processes or emits an event.
    ///
    /// - Parameters:
    ///   - event: The event that occurred.
    ///   - sessionID: The identifier of the active agent session.
    func onEvent(_ event: AgentEvent, sessionID: String) async
}
