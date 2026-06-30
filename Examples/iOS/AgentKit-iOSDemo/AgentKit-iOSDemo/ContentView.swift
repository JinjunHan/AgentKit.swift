// ContentView.swift
// AgentKit-iOSDemo
//
// SPDX-License-Identifier: MIT

import SwiftUI
import AgentKit

struct ContentView: View {

    // MARK: - Properties

    @StateObject private var viewModel = ChatViewModel()
    @State private var showingSettings = false

    // MARK: - View Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                messageRow(message)
                                    .id(message.id)
                            }

                            // Tool Call Status Loader
                            if let toolCall = viewModel.activeToolCall {
                                toolCallRow(toolCall)
                                    .id("active_tool_call")
                            }
                            
                            // Bottom anchor for auto-scrolling
                            Color.clear
                                .frame(height: 1)
                                .id("bottom_anchor")
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onReceive(viewModel.$messages) { _ in
                        withAnimation {
                            proxy.scrollTo("bottom_anchor", anchor: .bottom)
                        }
                    }
                    .onReceive(viewModel.$activeToolCall) { _ in
                        withAnimation {
                            proxy.scrollTo("bottom_anchor", anchor: .bottom)
                        }
                    }
                    .onReceive(viewModel.$inputMessage) { _ in
                        withAnimation {
                            proxy.scrollTo("bottom_anchor", anchor: .bottom)
                        }
                    }
                }

                // Error Indicator
                if let errorMessage = viewModel.errorMessage {
                    errorBanner(errorMessage)
                }

                // Bottom Input Area
                inputBar
            }
            .navigationTitle("AgentKit iOS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: viewModel.clearChat) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .disabled(viewModel.isGenerating)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: viewModel)
            }
        }
    }

    // MARK: - View Builders

    @ViewBuilder
    private func messageRow(_ message: Message) -> some View {
        HStack {
            if message.role == .user {
                Spacer()
                Text(message.content ?? "")
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: 280, alignment: .trailing)
            } else if message.role == .assistant {
                let content = message.content ?? ""
                let reasoning = message.reasoningContent ?? ""
                if !content.isEmpty || !message.toolCalls.isEmpty || !reasoning.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        if !reasoning.isEmpty {
                            DisclosureGroup {
                                Text(reasoning)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 4)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "brain")
                                    Text("思考过程 (Thinking...)")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.bottom, 4)
                        }

                        if !content.isEmpty {
                            Text(content)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        if !message.toolCalls.isEmpty {
                            ForEach(message.toolCalls) { tc in
                                Text("🔧 Requested tool call: \(tc.function.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: 280, alignment: .leading)
                    Spacer()
                }
            } else {
                // System or Tool log
                Spacer()
                Text(message.content ?? "")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemBackground))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func toolCallRow(_ toolCall: ToolCall) -> some View {
        HStack {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Executing tool: \(toolCall.function.name)...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemYellow).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            Spacer()
        }
    }

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.white)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.85))
            .animation(.easeInOut, value: viewModel.errorMessage)
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Message the Agent...", text: $viewModel.inputMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                    .lineLimit(1...5)

                Button {
                    Task {
                        await viewModel.sendMessage()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            viewModel.inputMessage.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isGenerating
                            ? Color.secondary
                            : Color.blue
                        )
                }
                .disabled(viewModel.inputMessage.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isGenerating)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))
        }
    }
}

#Preview {
    ContentView()
}
