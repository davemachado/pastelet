import Cocoa
import Carbon

import Combine

class HotKeyManager: ObservableObject {
    let hotKeySubject = PassthroughSubject<Void, Never>()
    
    private var hotKeyRef: EventHotKeyRef?
    
    init() {
        registerHotKey()
    }
    
    private func registerHotKey() {
        // HotKey ID
        let hotKeyID = EventHotKeyID(signature: OSType(0x5053544C), id: 1) // 'PSTL', 1
        
        // Modifier: Cmd (cmdKey) + Shift (shiftKey)
        // Carbon modifiers: cmdKey = 1<<8 (256), shiftKey = 1<<9 (512)
        // Swift/Carbon usage:
        let modifiers = cmdKey | shiftKey
        
        // Key Code: 'V'
        // ANSI V is 9.
        let keyCode = 9
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        // Install handler
        InstallEventHandler(GetApplicationEventTarget(), { (handler, event, userData) -> OSStatus in
            // Forward to manager instance
            DispatchQueue.main.async {
                HotKeyManager.shared.handleHotKey()
            }
            return noErr
        }, 1, &eventType, nil, nil)
        
        // Register
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status != noErr {
            print("Failed to register hotkey: \(status)")
        }
    }
    
    // Singleton for the C-callback to access
    static let shared = HotKeyManager()
    
    private func handleHotKey() {
        hotKeySubject.send()
    }
}
