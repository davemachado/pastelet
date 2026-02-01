import SwiftUI

struct SettingsView: View {
    @ObservedObject var snippetManager: SnippetManager
    @State private var selectedTab: String = "general"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
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
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gear")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("General Settings")
                .font(.title)
            Text("Configuration options for History size and excluded apps will appear here.")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
