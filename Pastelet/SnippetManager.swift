import Foundation
import Combine

struct Snippet: Codable, Identifiable {
    var id = UUID()
    var title: String
    var content: String
}

struct SnippetFolder: Codable, Identifiable {
    var id = UUID()
    var title: String
    var snippets: [Snippet]
}

class SnippetManager: ObservableObject {
    @Published var folders: [SnippetFolder] = []
    
    private let storageKey = "SavedSnippets"
    
    init() {
        loadSnippets()
        
        // If empty, seed with examples (Onboarding)
        if folders.isEmpty {
            seedExamples()
        }
    }
    
    func addSnippet(_ snippet: Snippet, to folderIndex: Int) {
        if folderIndex < folders.count {
            folders[folderIndex].snippets.append(snippet)
            saveSnippets()
        }
    }
    
    private func seedExamples() {
        folders = [
            SnippetFolder(title: "📨 Email", snippets: [
                Snippet(title: "Signature", content: "\nBest regards,\n\nDave\nSent from Pastelet"),
                Snippet(title: "Meeting Invite", content: "Hi team,\n\nI'd like to schedule a quick sync to discuss the project. Are you free at 2 PM?")
            ]),
            SnippetFolder(title: "💻 Code", snippets: [
                Snippet(title: "Swift Singleton", content: "static let shared = Manager()"),
                Snippet(title: "SwiftUI Body", content: "var body: some View {\n    Text(\"Hello\")\n}")
            ]),
            SnippetFolder(title: "¯\\_(ツ)_/¯ Kaomoji", snippets: [
                Snippet(title: "Shrug", content: "¯\\_(ツ)_/¯"),
                Snippet(title: "Table Flip", content: "(╯°□°）╯︵ ┻━┻")
            ])
        ]
        saveSnippets()
    }
    
    private func loadSnippets() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            if let decoded = try? JSONDecoder().decode([SnippetFolder].self, from: data) {
                folders = decoded
            }
        }
    }
    
    func resetToFactorySettings() {
        folders.removeAll()
        // Clear from disk immediately
        UserDefaults.standard.removeObject(forKey: storageKey)
        // Re-seed
        seedExamples()
    }
    
    private func saveSnippets() {
        if let encoded = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}
