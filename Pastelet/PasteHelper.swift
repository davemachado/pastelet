import Cocoa
import ApplicationServices

class PasteHelper {
    static func paste(item: ClipboardItem) {
        // 1. Set Clipboard Content
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        
        // 2. Hide our app (so focus returns to previous app)
        NSApp.hide(nil)
        
        // 3. Wait a moment for focus to switch, then simulate Cmd+V
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            simulatePasteCommand()
        }
    }
    
    private static func simulatePasteCommand() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Cmd Key
        let cmdKey: UInt16 = 55 // kVK_Command
        // V Key
        let vKey: UInt16 = 9    // kVK_ANSI_V
        
        // Cmd Down
        if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: true) {
            cmdDown.flags = .maskCommand
            cmdDown.post(tap: .cghidEventTap)
        }
        
        // V Down
        if let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true) {
            vDown.flags = .maskCommand
            vDown.post(tap: .cghidEventTap)
        }
        
        // V Up
        if let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) {
            vUp.flags = .maskCommand
            vUp.post(tap: .cghidEventTap)
        }
        
        // Cmd Up
        if let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: false) {
            cmdUp.flags = []
            cmdUp.post(tap: .cghidEventTap)
        }
    }
}
