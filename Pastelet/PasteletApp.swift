//
//  PasteletApp.swift
//  Pastelet
//
//  Created by Dave Machado on 1/31/26.
//

import SwiftUI

@main
struct PasteletApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Global Managers
    @StateObject var clipboardManager = ClipboardManager()
    @StateObject var windowManager: AppWindowManager
    
    init() {
        let cbManager = ClipboardManager()
        _clipboardManager = StateObject(wrappedValue: cbManager)
        _windowManager = StateObject(wrappedValue: AppWindowManager(clipboardManager: cbManager))
    }
    
    var body: some Scene {
        MenuBarExtra("Pastelet", systemImage: "clipboard") {
            // Show recent history (limit to top 15)
            ForEach(clipboardManager.history.prefix(15)) { item in
                Button {
                    PasteHelper.paste(item: item)
                } label: {
                    Text(item.content.prefix(30) + (item.content.count > 30 ? "..." : ""))
                }
            }
            
            if !clipboardManager.history.isEmpty {
                Divider()
            }
            
            Button("Clear History") {
                clipboardManager.history.removeAll()
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}


class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // AppWindowManager handles permissions check on init now
    }
}


