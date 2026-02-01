import Cocoa
import SwiftUI
import Combine

@MainActor
class AppWindowManager: NSObject, ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private let clipboardManager: ClipboardManager
    private let snippetManager: SnippetManager
    
    // Window Controllers
    private var permissionsWindowController: NSWindowController?
    private var settingsWindowController: NSWindowController?


    init(clipboardManager: ClipboardManager, snippetManager: SnippetManager) {
        self.clipboardManager = clipboardManager
        self.snippetManager = snippetManager
        super.init()
        
        // Check permissions on launch
        checkPermissions()
        
        // Subscribe to HotKey
        HotKeyManager.shared.hotKeySubject
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.toggleHistory()
            }
            .store(in: &cancellables)
    }
    
    private func checkPermissions() {
        // kAXTrustedCheckOptionPrompt: true forces the system to show the "App wants access" dialog
        // which registers it in the System Settings list.
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            showPermissionsWindow()
        }
    }
    
    private func showPermissionsWindow() {
        if permissionsWindowController == nil {
            let contentView = PermissionsView()
            let hostingController = NSHostingController(rootView: contentView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Permissions Required"
            window.titlebarAppearsTransparent = true
            window.contentViewController = hostingController
            
            permissionsWindowController = NSWindowController(window: window)
        }
        
        NSApp.activate(ignoringOtherApps: true)
        permissionsWindowController?.showWindow(nil)
        permissionsWindowController?.window?.makeKeyAndOrderFront(nil)
    }
    
    func openSettings() {
        if settingsWindowController == nil {
            let contentView = SettingsView(clipboardManager: clipboardManager, snippetManager: snippetManager)
            let hostingController = NSHostingController(rootView: contentView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 450),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Pastelet Settings"
            window.contentViewController = hostingController
            
            settingsWindowController = NSWindowController(window: window)
        }
        
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    func toggleHistory() {
        // Trigger the native Context Menu popup
        popUpHistoryMenu()
    }
    
    private func getCaretRect() -> CGRect? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        
        // 1. Get Focused Element
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard result == .success, let element = focusedElement else { return nil }
        let axElement = element as! AXUIElement
        
        // 2. Get Selected Range (which is the caret if length is 0)
        var rangeValue: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
        guard rangeResult == .success, let range = rangeValue else { return nil }
        
        // 3. Get Bounds for that Range
        var boundsValue: AnyObject?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(axElement, kAXBoundsForRangeParameterizedAttribute as CFString, range, &boundsValue)
        
        if boundsResult == .success, let boundsVal = boundsValue {
             // 4. Unwrap AXValue to CGRect
             var rect = CGRect.zero
             let axVal = boundsVal as! AXValue
             AXValueGetValue(axVal, .cgRect, &rect)
             return rect
        }
        
        return nil
    }
    
    private func popUpHistoryMenu() {
        // 1. Calculate Position FIRST
        var location = NSEvent.mouseLocation
        
        if let caretRect = getCaretRect() {
            if let primaryScreen = NSScreen.screens.first {
                // Caret Y is from top. Cocoa Y = ScreenHeight - (CaretTop + CaretHeight)
                let correctedY = primaryScreen.frame.height - (caretRect.origin.y + caretRect.height)
                location = NSPoint(x: caretRect.origin.x, y: correctedY - 5)
            }
        }
        
        // 2. Build Menu
        let menu = NSMenu(title: "Clipboard History")
        
        // --- HISTORY SECTION ---
        let history = clipboardManager.history
        
        if history.isEmpty {
             let item = NSMenuItem(title: "No History", action: nil, keyEquivalent: "")
             item.isEnabled = false
             menu.addItem(item)
        } else {
            // Chunk into groups of 10
            let maxItems = min(history.count, 100)
            let chunkSize = 10
            
            for chunkStart in stride(from: 0, to: maxItems, by: chunkSize) {
                let chunkEnd = min(chunkStart + chunkSize, maxItems)

                let folderTitle = "History \(chunkStart) - \(chunkEnd - 1)"
                
                let folderItem = NSMenuItem(title: folderTitle, action: nil, keyEquivalent: "")
                let subnet = NSMenu(title: folderTitle)
                
                for (index, item) in history[chunkStart..<chunkEnd].enumerated() {
                    let displayIndex = chunkStart + index
                    
                    var displayTitle = ""
                    var image: NSImage? = nil
                    
                    if item.type == .image {
                        displayTitle = "\(displayIndex). Captured Image"
                        if let id = item.imageID,
                           let loadedImage = ImageStorageService().loadImage(id: id) {
                            // Resize for menu icon (approx 20x20 usually good for menu items)
                            let size = NSSize(width: 20, height: 20)
                            let resized = NSImage(size: size)
                            resized.lockFocus()
                            loadedImage.draw(in: NSRect(origin: .zero, size: size))
                            resized.unlockFocus()
                            image = resized
                        }
                    } else {
                        let text = item.content.replacingOccurrences(of: "\n", with: " ")
                        displayTitle = "\(displayIndex). " + (text.count > 40 ? String(text.prefix(40)) + "..." : text)
                    }
                    
                    var keyEquiv = ""
                    var modifier: NSEvent.ModifierFlags = []
                    
                    if chunkStart == 0 {
                        keyEquiv = "\(displayIndex)"
                        modifier = .command
                    }
                    
                    let menuItem = NSMenuItem(title: displayTitle, action: #selector(pasteItem(_:)), keyEquivalent: keyEquiv)
                    if let img = image {
                        menuItem.image = img
                    }
                    if !modifier.isEmpty {
                        menuItem.keyEquivalentModifierMask = modifier
                    }
                    
                    menuItem.target = self
                    menuItem.representedObject = item
                    subnet.addItem(menuItem)
                }
                
                folderItem.submenu = subnet
                menu.addItem(folderItem)
            }
        }
        
        // --- SNIPPETS SECTION ---
        menu.addItem(NSMenuItem.separator())
        let snippetsHeader = NSMenuItem(title: "Snippets", action: nil, keyEquivalent: "")
        snippetsHeader.isEnabled = false
        menu.addItem(snippetsHeader)
        
        for folder in snippetManager.folders {
            let folderItem = NSMenuItem(title: folder.title, action: nil, keyEquivalent: "")
            let subnet = NSMenu(title: folder.title)
            
            for snippet in folder.snippets {
                 let menuItem = NSMenuItem(title: snippet.title, action: #selector(pasteSnippet(_:)), keyEquivalent: "")
                 menuItem.target = self
                 menuItem.representedObject = snippet
                 subnet.addItem(menuItem)
            }
            folderItem.submenu = subnet
            menu.addItem(folderItem)
        }
        
        // Edit Snippets Option REMOVED (Moved to Settings Window)
        
        // --- FOOTER SECTION ---
        menu.addItem(NSMenuItem.separator())
        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        
        // 3. Activate App & Pop Up
        NSApp.activate(ignoringOtherApps: true)
        if !menu.popUp(positioning: nil, at: location, in: nil) {
            NSApp.hide(nil)
        }
    }
    
    @objc func pasteItem(_ sender: NSMenuItem) {
        if let item = sender.representedObject as? ClipboardItem {
            PasteHelper.paste(item: item, manager: clipboardManager)
        }
    }
    
    @objc func pasteSnippet(_ sender: NSMenuItem) {
        if let snippet = sender.representedObject as? Snippet {
            let item = ClipboardItem(content: snippet.content, date: Date())
            PasteHelper.paste(item: item, manager: clipboardManager)
        }
    }
    
    @objc func clearHistory() {
        clipboardManager.clearHistory()
    }
}
