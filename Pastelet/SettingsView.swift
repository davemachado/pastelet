import SwiftUI

struct SettingsView: View {
    @ObservedObject var clipboardManager: ClipboardManager // Added dependency
    @ObservedObject var snippetManager: SnippetManager
    @State private var selectedTab: String = "general"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(clipboardManager: clipboardManager, snippetManager: snippetManager)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag("general")
            
            SnippetEditorView(manager: snippetManager)
                .tabItem {
                    Label("Snippets", systemImage: "list.bullet.clipboard")
                }
                .tag("snippets")
        }
        .frame(width: 700, height: 450)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var snippetManager: SnippetManager
    @StateObject private var launchAtLoginManager = LaunchAtLoginManager()
    @State private var showingResetAlert = false
    @State private var showingKeyRotationAlert = false
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { launchAtLoginManager.isEnabled },
                        set: { launchAtLoginManager.setEnabled($0) }
                    ))
                    .controlSize(.large)
                    
                    Divider()
                        .padding(.vertical, 8)
                        
                    Text("Security")
                        .font(.headline)
                        
                    Text("Your clipboard history is encrypted using a key stored in your Keychain. You can regenerate this key if needed.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Regenerate Encryption Key") {
                        showingKeyRotationAlert = true
                    }
                    .controlSize(.large)
                    
                    Divider()
                        .padding(.vertical, 8)

                    Text("Application Reset")
                        .font(.headline)
                    Text("Resetting the application will delete all custom snippets and clear your clipboard history. This action cannot be undone.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Factory Reset Pastelet", systemImage: "exclamationmark.triangle")
                    }
                    .controlSize(.large)
                }
                .padding(.vertical, 8)
            }
        }
        .formStyle(.grouped)
        .alert("Factory Reset", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset Everything", role: .destructive) {
                // Perform Reset
                clipboardManager.clearHistory()
                snippetManager.resetToFactorySettings()
            }
        } message: {
            Text("Are you sure? All your snippets and history will be permanently deleted.")
        }
        .alert("Regenerate Key?", isPresented: $showingKeyRotationAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Regenerate", role: .destructive) {
                clipboardManager.rotateEncryptionKey()
            }
        } message: {
            Text("This will generate a new encryption key and re-encrypt your current history. Previous backups if any may become unreadable.")
        }
    }
}
