import Cocoa
import Combine

struct RunningApp: Identifiable, Hashable {
    let id: String // Bundle ID
    let name: String
    let icon: NSImage?
}

class AppExclusionManager: ObservableObject {
    @Published var excludedBundleIDs: Set<String> = []
    
    private let storageKey = "ExcludedBundleIDs"
    
    init() {
        loadExclusions()
    }
    
    private func loadExclusions() {
        if let saved = UserDefaults.standard.array(forKey: storageKey) as? [String] {
            excludedBundleIDs = Set(saved)
        }
    }
    
    func saveExclusions() {
        UserDefaults.standard.set(Array(excludedBundleIDs), forKey: storageKey)
    }
    
    func isExcluded(bundleID: String) -> Bool {
        return excludedBundleIDs.contains(bundleID)
    }
    
    func addExclusion(_ bundleID: String) {
        excludedBundleIDs.insert(bundleID)
        saveExclusions()
    }
    
    func removeExclusion(_ bundleID: String) {
        excludedBundleIDs.remove(bundleID)
        saveExclusions()
    }
    
    // Helper to get Running Apps for the UI selection list
    func getRunningApplications() -> [RunningApp] {
        let apps = NSWorkspace.shared.runningApplications
        var runningApps: [RunningApp] = []
        
        for app in apps {
            if app.activationPolicy == .regular, // Only regular apps (with Dock icon)
               let bundleID = app.bundleIdentifier,
               let name = app.localizedName {
                
                // Skip ourselves
                if bundleID == Bundle.main.bundleIdentifier { continue }
                
                let icon = app.icon
                runningApps.append(RunningApp(id: bundleID, name: name, icon: icon))
            }
        }
        
        // Sort explicitly by name
        return runningApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
