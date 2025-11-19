import SwiftUI

struct LaunchAtLoginToggle: View {
    @State private var isEnabled = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Launch at Login", isOn: $isEnabled)
                .onChange(of: isEnabled) { newValue in
                    do {
                        try LaunchAtLoginHelper.shared.setEnabled(newValue)
                        errorMessage = nil
                    } catch {
                        // Revert toggle on error
                        isEnabled = !newValue
                        errorMessage = error.localizedDescription
                    }
                }
            
            Text("Automatically start Szwitch when you log in")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onAppear {
            isEnabled = LaunchAtLoginHelper.shared.isEnabled
        }
    }
}
