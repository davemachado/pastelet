import SwiftUI

struct SnippetEditorView: View {
    @ObservedObject var manager: SnippetManager
    @State private var selection: UUID?
    
    var body: some View {
        NavigationView {
            // Sidebar: Folders
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach($manager.folders) { $folder in
                        NavigationLink(destination: SnippetFolderDetailView(folder: $folder), tag: folder.id, selection: $selection) {
                            TextField("Folder Name", text: $folder.title)
                                .textFieldStyle(.plain)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteFolder(folder)
                            } label: {
                                Label("Delete Folder", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indices in
                        manager.folders.remove(atOffsets: indices)
                    }
                }
                .listStyle(.sidebar)
                
                // Bottom Toolbar
                Divider()
                HStack(spacing: 0) {
                    Button(action: addFolder) {
                        Image(systemName: "plus")
                            .frame(width: 32, height: 28)
                    }
                    .buttonStyle(.borderless)
                    
                    Divider().frame(height: 16)
                    
                    Button(action: deleteSelectedFolder) {
                        Image(systemName: "minus")
                            .frame(width: 32, height: 28)
                    }
                    .buttonStyle(.borderless)
                    .disabled(selection == nil)
                    
                    Spacer()
                }
                .frame(height: 29)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .navigationTitle("Folders")
            
            // Default Detail View
            Text("Select a Folder to Edit")
                .foregroundColor(.secondary)
        }
    }
    
    private func addFolder() {
        let newFolder = SnippetFolder(title: "New Folder", snippets: [])
        manager.folders.append(newFolder)
        // Auto-select the new folder
        selection = newFolder.id
    }
    
    private func deleteSelectedFolder() {
        if let sel = selection, let index = manager.folders.firstIndex(where: { $0.id == sel }) {
            manager.folders.remove(at: index)
            selection = nil
        }
    }
    
    private func deleteFolder(_ folder: SnippetFolder) {
        if let index = manager.folders.firstIndex(where: { $0.id == folder.id }) {
            manager.folders.remove(at: index)
            if selection == folder.id {
                selection = nil
            }
        }
    }
}

struct SnippetFolderDetailView: View {
    @Binding var folder: SnippetFolder
    @State private var selectedSnippetId: UUID?
    @State private var renamingSnippetId: UUID?
    @FocusState private var isRenaming: Bool
    
    var body: some View {
        VSplitView {
            // Top Pane: Snippet List Container
            VStack(spacing: 0) {
                // Custom Toolbar
                HStack(spacing: 16) {
                    Button(action: addSnippet) {
                        VStack(spacing: 2) {
                            Image(systemName: "note.text.badge.plus")
                                .font(.system(size: 16))
                            Text("Add Snippet")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: deleteSelectedSnippet) {
                        VStack(spacing: 2) {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                            Text("Delete")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedSnippetId == nil)
                    .foregroundColor(selectedSnippetId == nil ? .secondary : .primary)
                    
                    Spacer()
                    
                    Text("\(folder.snippets.count) Snippets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Snippet List
                List(selection: $selectedSnippetId) {
                    ForEach($folder.snippets) { $snippet in
                        Group {
                            if renamingSnippetId == snippet.id {
                                TextField("Untitled", text: $snippet.title)
                                    .focused($isRenaming)
                                    .textFieldStyle(.plain)
                                    .onSubmit {
                                        renamingSnippetId = nil
                                    }
                            } else {
                                Text(snippet.title.isEmpty ? "Untitled" : snippet.title)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 1) {
                                        // Explicitly select on single tap to ensure responsiveness
                                        selectedSnippetId = snippet.id
                                    }
                                    .simultaneousGesture(TapGesture(count: 2).onEnded {
                                        renamingSnippetId = snippet.id
                                        isRenaming = true
                                    })
                            }
                        }
                        .tag(snippet.id)
                    }
                    .onDelete { indices in
                        folder.snippets.remove(atOffsets: indices)
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 120)
                // Clear renaming state when selection changes elsewhere
                .onChange(of: selectedSnippetId) { _ in
                    renamingSnippetId = nil
                }
            }
            .frame(minHeight: 180)
            
            // Bottom Pane: Editor
            Group {
                if let selectedId = selectedSnippetId,
                   let index = folder.snippets.firstIndex(where: { $0.id == selectedId }) {
                    // Inline Editor for specific binding
                    VStack(spacing: 0) {
                        TextEditor(text: $folder.snippets[index].content)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .background(Color(NSColor.textBackgroundColor))
                } else {
                    Text("Select a snippet to edit")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.controlBackgroundColor))
                }
            }
            .frame(minHeight: 200)
        }
    }
    
    private func addSnippet() {
        let newSnippet = Snippet(title: "New Snippet", content: "")
        folder.snippets.append(newSnippet)
        selectedSnippetId = newSnippet.id
    }
    
    private func deleteSelectedSnippet() {
        if let selectedId = selectedSnippetId,
           let index = folder.snippets.firstIndex(where: { $0.id == selectedId }) {
            folder.snippets.remove(at: index)
            selectedSnippetId = nil
        }
    }
}
// SnippetDetailView is no longer used directly but kept if needed, or can be removed.

struct SnippetDetailView: View {
    @Binding var snippet: Snippet
    
    var body: some View {
        Form {
            TextField("Title", text: $snippet.title)
            
            Text("Content:")
            TextEditor(text: $snippet.content)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .frame(minHeight: 100)
        }
        .padding()
        .navigationTitle("Edit Snippet")
    }
}
