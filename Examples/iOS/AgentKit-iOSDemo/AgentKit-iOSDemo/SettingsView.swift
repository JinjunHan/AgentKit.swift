// SettingsView.swift
// AgentKit-iOSDemo
//
// SPDX-License-Identifier: MIT

import SwiftUI

/// Settings sheet allowing users to configure LLM provider settings and Agent options.
struct SettingsView: View {

    // MARK: - Properties

    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingErrorAlert = false
    @State private var showingSuccessAlert = false

    // MARK: - View Body

    var body: some View {
        NavigationStack {
            Form {
                // Provider Selection
                Section("Provider") {
                    Picker("LLM Provider", selection: $viewModel.selectedProvider) {
                        ForEach(ProviderType.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.selectedProvider) { _, newValue in
                        viewModel.selectedModel = newValue.defaultModel
                    }
                }

                // API Key Section (conditionally shown)
                if viewModel.selectedProvider.requiresAPIKey {
                    Section("API Authentication") {
                        switch viewModel.selectedProvider {
                        case .openAI:
                            SecureField("OpenAI API Key", text: $viewModel.apiKey)
                                .textInputAutocapitalization(.none)
                                .autocorrectionDisabled()
                        case .claude:
                            SecureField("Anthropic API Key", text: $viewModel.anthropicAPIKey)
                                .textInputAutocapitalization(.none)
                                .autocorrectionDisabled()
                        case .deepSeek:
                            SecureField("DeepSeek API Key", text: $viewModel.deepSeekAPIKey)
                                .textInputAutocapitalization(.none)
                                .autocorrectionDisabled()
                        case .openRouter:
                            SecureField("OpenRouter API Key", text: $viewModel.openRouterAPIKey)
                                .textInputAutocapitalization(.none)
                                .autocorrectionDisabled()
                        case .custom:
                            SecureField("Custom API Key", text: $viewModel.customAPIKey)
                                .textInputAutocapitalization(.none)
                                .autocorrectionDisabled()
                        default:
                            EmptyView()
                        }

                        Text("API keys are saved locally in UserDefaults.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Custom Provider settings
                if viewModel.selectedProvider == .custom {
                    Section("Custom Server") {
                        Picker("Protocol", selection: $viewModel.customProtocol) {
                            ForEach(CustomProtocolType.allCases) { proto in
                                Text(proto.rawValue).tag(proto)
                            }
                        }
                        
                        TextField("https://api.example.com", text: $viewModel.customBaseURL)
                            .textInputAutocapitalization(.none)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                }

                // Apple On-Device info
                if viewModel.selectedProvider == .appleOnDevice {
                    Section("Apple On-Device") {
                        Label {
                            Text("No API key required. Runs entirely on-device using Apple Intelligence.")
                        } icon: {
                            Image(systemName: "apple.logo")
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }
                }

                // Model Configuration
                Section("Model Configuration") {
                    if viewModel.fetchedModels.isEmpty {
                        TextField("Model Name", text: viewModel.selectedProvider == .custom ? $viewModel.customModel : $viewModel.selectedModel)
                            .textInputAutocapitalization(.none)
                            .autocorrectionDisabled()
                    } else {
                        HStack {
                            Picker("LLM Model", selection: viewModel.selectedProvider == .custom ? $viewModel.customModel : $viewModel.selectedModel) {
                                ForEach(viewModel.fetchedModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .pickerStyle(.menu)
                            
                            Spacer()
                            
                            Button(action: {
                                viewModel.fetchedModels.removeAll()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if viewModel.selectedProvider != .appleOnDevice {
                        Button {
                            Task {
                                await viewModel.fetchModels()
                            }
                        } label: {
                            HStack {
                                if viewModel.isFetchingModels {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.down.doc")
                                }
                                Text("Fetch Models from Server")
                            }
                        }
                        .disabled(viewModel.isFetchingModels || viewModel.isTestingConnection)

                        Button {
                            Task {
                                await viewModel.testConnection()
                            }
                        } label: {
                            HStack {
                                if viewModel.isTestingConnection {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "network")
                                }
                                Text("Test Model Configuration")
                            }
                        }
                        .disabled(viewModel.isTestingConnection || viewModel.isFetchingModels)
                    }

                    Toggle("Enable Streaming", isOn: $viewModel.streamingEnabled)
                }

                // Agent Behavior
                Section("Agent Behavior") {
                    LabeledContent("System Instructions") {
                        TextEditor(text: $viewModel.systemPrompt)
                            .frame(minHeight: 100)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                // Observability
                Section("Observability") {
                    Toggle("Enable Tracing", isOn: $viewModel.tracingEnabled)

                    Text("When enabled, a performance trace report is shown after each conversation turn.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Agent Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onReceive(viewModel.$errorMessage) { newValue in
                if newValue != nil {
                    showingErrorAlert = true
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
            .onReceive(viewModel.$successMessage) { newValue in
                if newValue != nil {
                    showingSuccessAlert = true
                }
            }
            .alert("Success", isPresented: $showingSuccessAlert) {
                Button("OK", role: .cancel) {
                    viewModel.successMessage = nil
                }
            } message: {
                Text(viewModel.successMessage ?? "Connection successful!")
            }
        }
    }
}

#Preview {
    SettingsView(viewModel: ChatViewModel())
}
