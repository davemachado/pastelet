import Foundation
import ServiceManagement
import os
import Combine

class LaunchAtLoginManager: ObservableObject {
    @Published var isEnabled: Bool = false
    
    init() {
        checkStatus()
    }
    
    func checkStatus() {
        // SMAppService.mainApp is available from macOS 13.0
        // We will assume the target is appropriate or this code will be guarded if needed,
        // but for a modern app, 13.0+ is reasonable.
        let status = SMAppService.mainApp.status
        isEnabled = (status == .enabled)
    }
    
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled { return }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status == .notRegistered { return }
                try SMAppService.mainApp.unregister()
            }
            checkStatus()
        } catch {
            print("Failed to update launch at login status: \(error)")
            // Update UI to reflect actual state even if it failed
            DispatchQueue.main.async {
                self.checkStatus()
            }
        }
    }
}
