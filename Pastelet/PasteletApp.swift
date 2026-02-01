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
            PasteletMenuView(clipboardManager: clipboardManager, windowManager: windowManager)
        }
    }
}

struct PasteletMenuView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var windowManager: AppWindowManager
    
    var body: some View {
        // Show recent history (limit to top 15)
        ForEach(clipboardManager.history.prefix(15)) { item in
            Button {
                PasteHelper.paste(item: item, manager: clipboardManager)
            } label: {
                if item.type == .image, let id = item.imageID {
                    ImageLabel(imageID: id)
                } else {
                    Text(item.content.prefix(30) + (item.content.count > 30 ? "..." : ""))
                }
            }
        }
        
        if !clipboardManager.history.isEmpty {
            Divider()
        }
        
        Button("Settings...") {
            windowManager.openSettings()
        }
        
        Button("Clear History") {
            clipboardManager.clearHistory()
        }
        Divider()
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}


struct ImageLabel: View {
    let imageID: UUID
    @State private var image: NSImage?
    
    var body: some View {
        HStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "photo")
            }
            Text("Captured Image")
        }
        .onAppear {
            if let loaded = ImageStorageService().loadImage(id: imageID) {
                self.image = loaded
            }
        }
    }
}


class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // AppWindowManager handles permissions check on init now
    }
}


