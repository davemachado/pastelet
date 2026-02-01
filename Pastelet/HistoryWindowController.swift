import Cocoa
import SwiftUI

// Custom Panel/Window Controller for Floating History
class HistoryWindowController: NSWindowController {
    var clipboardManager: ClipboardManager
    
    init(clipboardManager: ClipboardManager) {
        self.clipboardManager = clipboardManager
        
        // Create Host Controller
        let contentView = HistoryView(
            clipboardManager: clipboardManager,
            onSelect: { item in
                PasteHelper.paste(item: item, manager: clipboardManager)
                // We don't close immediately here because PasteHelper hides the app, 
                // effectively closing the window's visual prominence, but we should clear state.
                // Actually, PasteHelper logic hides the app.
            },
            onCancel: {
                NSApp.hide(nil)
            }
        )
        
        let hostingController = NSHostingController(rootView: contentView)
        
        // Create Panel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 400),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView], // borderless-ish
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.contentViewController = hostingController
        panel.backgroundColor = .clear // For VisualEffectView
        panel.hasShadow = true
        
        super.init(window: panel)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func show() {
        if let window = window {
            let mouseLocation = NSEvent.mouseLocation
            // Mouse location is in global screen coordinates (bottom-left origin)
            
            // Default position: slightly below and right of cursor
            var newOrigin = NSPoint(x: mouseLocation.x, y: mouseLocation.y - window.frame.height)
            
            // Constraint to screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                
                // Keep X within bounds
                if newOrigin.x + window.frame.width > screenFrame.maxX {
                    newOrigin.x = screenFrame.maxX - window.frame.width
                }
                if newOrigin.x < screenFrame.minX {
                    newOrigin.x = screenFrame.minX
                }
                
                // Keep Y within bounds
                if newOrigin.y < screenFrame.minY {
                    // If it goes below, show it ABOVE the cursor
                    newOrigin.y = mouseLocation.y
                    
                    // If that also goes off top (rare for 400px), clamp to top
                    if newOrigin.y + window.frame.height > screenFrame.maxY {
                        newOrigin.y = screenFrame.maxY - window.frame.height
                    }
                }
            }
            
            window.setFrameOrigin(newOrigin)
        }
        
        // Make active
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
