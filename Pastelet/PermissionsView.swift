import SwiftUI

struct PermissionsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 50))
                .foregroundStyle(.red)
            
            Text("Permissions Required")
                .font(.title2)
                .bold()
            
            Text("To paste directly into other apps, Pastelet needs Accessibility permissions.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Open System Settings") {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Text("After enabling, please restart the app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 300, height: 300)
    }
}
