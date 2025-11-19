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
                    Button(action: {
                        profileManager.switchProfile(to: profile)
                    }) {
                        HStack {
                            if profileManager.activeProfileId == profile.id {
                                Image(systemName: "checkmark")
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                if let username = profile.githubUsername {
                                    Text("@\(username)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                if profileManager.profiles.isEmpty {
                    Text("No profiles configured")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }
                
                Divider()
                
                Button(action: {
                    openWindow(id: "settings")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }) {
                    Label("Settings", systemImage: "gear")
                }
                .keyboardShortcut(",", modifiers: .command)
                
                Divider()
                
                Button("Quit Szwitch") {
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
            .defaultPosition(.center)
            
            Window("About Szwitch", id: "about") {
                AboutView()
            }
            .windowResizability(.contentSize)
            .defaultPosition(.center)
        }
    }
}
