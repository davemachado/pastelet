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
    @StateObject var snippetManager = SnippetManager()
    @StateObject var windowManager: AppWindowManager
    
    init() {
        let cbManager = ClipboardManager()
        let snipManager = SnippetManager()
        _clipboardManager = StateObject(wrappedValue: cbManager)
        _snippetManager = StateObject(wrappedValue: snipManager)
        _windowManager = StateObject(wrappedValue: AppWindowManager(clipboardManager: cbManager, snippetManager: snipManager))
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
            
            SettingsLink {
                Text("Settings...")
            }
            
            Button("Clear History") {
                clipboardManager.history.removeAll()
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        
        Settings {
            SettingsView(snippetManager: snippetManager)
        }
    }
}


class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // AppWindowManager handles permissions check on init now
    }
}


