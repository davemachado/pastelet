import SwiftUI
import UniformTypeIdentifiers

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
            
            ExclusionSettingsView(manager: clipboardManager.appExclusionManager)
                .tabItem {
                    Label("Exclusions", systemImage: "xmark.circle")
                }
                .tag("exclusions")
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

            
            Section {
                HStack {
                    Spacer()
                    #if DEBUG
                    VStack(spacing: 2) {
                        Text("Development Build")
                        if let path = Bundle.main.executablePath,
                           let attr = try? FileManager.default.attributesOfItem(atPath: path),
                           let date = attr[.modificationDate] as? Date {
                            Text("Built: \(date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    #else
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    #endif
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)
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

struct ExclusionSettingsView: View {
    @ObservedObject var manager: AppExclusionManager
    @State private var selectedRunningApp: RunningApp?
    @State private var runningApps: [RunningApp] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading) {
                Text("App Exclusions")
                    .font(.headline)
                Text("Pastelet will not record clipboard history from these applications.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            HStack(spacing: 0) {
                // Left: Excluded List
                List {
                    if manager.excludedBundleIDs.isEmpty {
                        Text("No excluded apps")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    ForEach(Array(manager.excludedBundleIDs).sorted(), id: \.self) { bundleID in
                        let info = getAppInfo(for: bundleID)
                        HStack {
                            if let icon = info.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "app.dashed")
                            }
                            
                            Text(info.name)
                            Spacer()
                            Button {
                                manager.removeExclusion(bundleID)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(minWidth: 200)
                
                Divider()
                
                // Right: Add New
                VStack(alignment: .leading) {
                    Text("Add Exclusion")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    Text("Select a running application to exclude:")
                        .font(.caption)
                    
                    List(runningApps, id: \.id, selection: $selectedRunningApp) { app in
                        HStack {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            Text(app.name)
                        }
                        .tag(app) // Helper for selection if using List selection
                    }
                    .listStyle(.inset)
                    
                    Button("Exclude Selected") {
                        if let app = selectedRunningApp {
                            manager.addExclusion(app.id)
                            selectedRunningApp = nil
                        }
                    }
                    .disabled(selectedRunningApp == nil)
                    .padding(.top)
                    
                    Divider()
                        .padding(.vertical)
                    
                    Button("Browse Applications...") {
                         browseForApp()
                    }
                }
                .padding()
                .frame(width: 250)
            }
        }
        .onAppear {
            refreshRunningApps()
        }
    }
    
    func refreshRunningApps() {
        runningApps = manager.getRunningApplications()
    }
    
    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let bundle = Bundle(url: url),
                   let bundleID = bundle.bundleIdentifier {
                    manager.addExclusion(bundleID)
                }
            }
        }
    }
    
    // Helper to get icon/name even if app is closed
    func getAppInfo(for bundleID: String) -> (name: String, icon: NSImage?) {
        // 1. Check running apps first (faster)
        if let app = runningApps.first(where: { $0.id == bundleID }) {
            return (app.name, app.icon)
        }
        
        // 2. Resolve from disk
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            
            // Try to get localized name
            var name = url.deletingPathExtension().lastPathComponent
            if let bundle = Bundle(url: url),
               let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                name = displayName
            } else if let bundle = Bundle(url: url),
               let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
                name = bundleName
            }
            
            return (name, icon)
        }
        
        return (bundleID, nil)
    }
}
