import Cocoa
import Combine

struct ClipboardItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let content: String
    let date: Date
    // Future: appBundleIdentifier, type (image/text)
    
    // Equatable to prevent duplicates
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        return lhs.content == rhs.content
    }
}

class ClipboardManager: ObservableObject {
    @Published var history: [ClipboardItem] = []
    
    private var timer: Timer?
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    
    private let maxHistorySize = 50
    private let storageKey = "ClipboardHistory"
    
    init() {
        self.lastChangeCount = pasteboard.changeCount
        loadHistory()
        startMonitoring()
    }
    
    private func startMonitoring() {
        // Poll every 0.5 seconds for changes
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }
    
    private func checkForChanges() {
        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount
            
            // For now, only handle plain text
            if let newString = pasteboard.string(forType: .string) {
                // Avoid capturing own paste action if possible (complex)
                // or just debounce.
                // Or simply add.
                
                // Avoid adding duplicate of the *most recent* item
                if let last = history.first, last.content == newString {
                    return
                }
                
                let newItem = ClipboardItem(content: newString, date: Date())
                addItem(newItem)
            }
        }
    }
    
    private func addItem(_ item: ClipboardItem) {
        // Remove duplicate if it exists elsewhere
        history.removeAll { $0.content == item.content }
        
        // Insert at top
        history.insert(item, at: 0)
        
        // Cap size
        if history.count > maxHistorySize {
            history.removeLast()
        }
        
        saveHistory()
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            if let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
                history = decoded
            }
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    /// Called when user selects an item to paste
    func paste(item: ClipboardItem) {
        // 1. Move to pasteboard
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
    }
    
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }
}
