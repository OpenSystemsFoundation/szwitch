import SwiftUI
import SzwitchLib

@main
struct SzwitchApp: App {
    @StateObject private var profileManager = ProfileManager()
    @Environment(\.openWindow) var openWindow
    
    var body: some Scene {
        Group {
            MenuBarExtra("Szwitch", systemImage: "person.2.circle") {
                // Profile List
                ForEach(profileManager.profiles) { profile in
                    Toggle(isOn: Binding(
                        get: { profileManager.activeProfileId == profile.id },
                        set: { _ in profileManager.switchProfile(to: profile) }
                    )) {
                        Text(profile.name)
                    }
                    .toggleStyle(.checkbox)
                }
                
                if profileManager.profiles.isEmpty {
                    Text("No profiles")
                }
                
                Divider()
                
                Button("Settings") {
                    openWindow(id: "settings")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                
                Divider()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .menuBarExtraStyle(.menu)
            
            WindowGroup("Szwitch Settings", id: "settings") {
                SettingsView()
                    .environmentObject(profileManager)
            }
            .windowResizability(.contentSize)
        }
    }
}
