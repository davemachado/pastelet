import Cocoa
import SwiftUI
import Combine

@MainActor
class AppWindowManager: NSObject, ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private let clipboardManager: ClipboardManager
    
    // We still manage the permissions window here
    private var permissionsWindowController: NSWindowController?

    init(clipboardManager: ClipboardManager) {
        self.clipboardManager = clipboardManager
        // Initialize NSObject superclass
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
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(axElement, kAXBoundsForRangeParameterizedAttribute as CFString, range as! CFTypeRef, &boundsValue)
        
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
                let screenHeight = primaryScreen.frame.height
                let correctedY = screenHeight - (caretRect.origin.y + caretRect.height)
                location = NSPoint(x: caretRect.origin.x, y: correctedY - 5)
            }
        }
        
        // 2. Build Menu
        let menu = NSMenu(title: "Clipboard History")
        
        let history = clipboardManager.history
        
        if history.isEmpty {
             let item = NSMenuItem(title: "No History", action: nil, keyEquivalent: "")
             item.isEnabled = false
             menu.addItem(item)
        } else {
            // Chunk into groups of 10
            // We'll show up to 100 items (10 groups)
            let maxItems = min(history.count, 100)
            let chunkSize = 10
            
            for chunkStart in stride(from: 0, to: maxItems, by: chunkSize) {
                let chunkEnd = min(chunkStart + chunkSize, maxItems)
                let chunkRange = chunkStart..<chunkEnd
                let folderTitle = "History \(chunkStart) - \(chunkEnd - 1)"
                
                // Create the Folder Item
                let folderItem = NSMenuItem(title: folderTitle, action: nil, keyEquivalent: "")
                
                // Create the Submenu
                let subnet = NSMenu(title: folderTitle)
                
                for (index, item) in history[chunkRange].enumerated() {
                    // Flatten newlines and truncate
                    let text = item.content.replacingOccurrences(of: "\n", with: " ")
                    // Include the index prefix 0...9 for clarity
                    let displayIndex = chunkStart + index
                    let truncatedText = text.count > 40 ? String(text.prefix(40)) + "..." : text
                    let displayTitle = "\(displayIndex). \(truncatedText)"
                    
                    // Determine Hotkey (Only for the first 10 items 0-9)
                    // 0 -> Cmd+0, 1 -> Cmd+1...
                    var keyEquiv = ""
                    var modifier: NSEvent.ModifierFlags = []
                    
                    if chunkStart == 0 {
                        keyEquiv = "\(displayIndex)"
                        modifier = .command
                    }
                    
                    let menuItem = NSMenuItem(title: displayTitle, action: #selector(pasteItem(_:)), keyEquivalent: keyEquiv)
                    if !modifier.isEmpty {
                        menuItem.keyEquivalentModifierMask = modifier
                    }
                    
                    menuItem.target = self
                    menuItem.representedObject = item
                    subnet.addItem(menuItem)
                }
                
                // Attach submenu to folder
                folderItem.submenu = subnet
                menu.addItem(folderItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        
        // 3. Activate App
        NSApp.activate(ignoringOtherApps: true)
        // 4. Pop Up
        // Pop up the menu at the calculated or fallback location
        // popUp returns true if an item was selected, false if dismissed.
        if !menu.popUp(positioning: nil, at: location, in: nil) {
            // If user cancelled (clicked outside/Escape), return focus to previous app immediately.
            NSApp.hide(nil)
        }
    }
    
    @objc func pasteItem(_ sender: NSMenuItem) {
        if let item = sender.representedObject as? ClipboardItem {
            PasteHelper.paste(item: item)
        }
    }
    
    @objc func clearHistory() {
        clipboardManager.history.removeAll()
    }
}
