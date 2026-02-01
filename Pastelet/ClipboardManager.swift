import Cocoa
import Combine

enum ItemType: String, Codable {
    case text
    case image
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let content: String // Text preview or placeholder
    let date: Date
    var type: ItemType = .text
    var imageID: UUID?
    
    // Equatable to prevent duplicates
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        if lhs.type != rhs.type { return false }
        if lhs.type == .image {
            return lhs.imageID == rhs.imageID
        }
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
    
    private let encryptionService = EncryptionService()
    private let imageStorageService = ImageStorageService()
    
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
            
            // 1. Check for Image
            if let image = NSImage(pasteboard: pasteboard) {
                // Save image
                if let imageID = imageStorageService.saveImage(image) {
                     let newItem = ClipboardItem(
                        content: "Image",
                        date: Date(),
                        type: .image,
                        imageID: imageID
                    )
                    addItem(newItem)
                }
                return
            }
            
            // 2. Check for Text (Fallback)
            if let newString = pasteboard.string(forType: .string) {
                // Avoid capturing own paste action if possible (complex)
                // or just debounce.
                // Or simply add.
                
                // Avoid adding duplicate of the *most recent* item
                if let last = history.first, last.type == .text, last.content == newString {
                    return
                }
                
                let newItem = ClipboardItem(content: newString, date: Date(), type: .text)
                addItem(newItem)
            }
        }
    }
    
    private func addItem(_ item: ClipboardItem) {
        // Remove duplicate if it exists elsewhere
        history.removeAll { 
            if $0.type == .image, let id1 = $0.imageID, let id2 = item.imageID {
                 return id1 == id2
            }
            return $0.content == item.content 
        }
        
        // Insert at top
        history.insert(item, at: 0)
        
        // Cap size
        if history.count > maxHistorySize {
            let removed = history.removeLast()
            if removed.type == .image, let id = removed.imageID {
                imageStorageService.deleteImage(id: id)
            }
        }
        
        saveHistory()
    }
    
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            // Check if key exists (before getOrGenerateKey potentially makes a new one)
            let keyExists = encryptionService.hasKeyInKeychain()
            
            // 1. Try Decrypting (New Path)
            if let decrypted = encryptionService.decrypt(data),
               let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: decrypted) {
                history = decoded
                return
            }
            
            // 2. Fallback: Try Legacy Plaintext
            if let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
                print("Loaded legacy plaintext history. Will define migration on next save.")
                history = decoded
                return
            }
            
            // 3. Failure Scenario
            if !keyExists {
                // We have data, but no key to decrypt it, and it wasn't plaintext.
                // This means the key was lost/deleted.
                print("Encryption key missing. History is unreadable.")
                DispatchQueue.main.async {
                    self.showMissingKeyAlert()
                }
            }
        }
    }
    
    private func showMissingKeyAlert() {
        // Bring app to front so alert is visible
        NSApp.activate(ignoringOtherApps: true)
        
        let alert = NSAlert()
        alert.messageText = "Encryption Key Missing"
        alert.informativeText = "Your clipboard history has been reset because the encryption key could not be found in your Keychain."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            // 3. Encrypt before saving
            if let encrypted = encryptionService.encrypt(encoded) {
                UserDefaults.standard.set(encrypted, forKey: storageKey)
            }
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
        imageStorageService.deleteAllImages()
        saveHistory()
    }
    
    func rotateEncryptionKey() {
        if encryptionService.regenerateKey() {
            // Re-save current in-memory history with new key
            saveHistory()
            print("Encryption key rotated and history re-saved.")
        }
    }
    
    func updateChangeCount() {
        lastChangeCount = pasteboard.changeCount
    }
}
