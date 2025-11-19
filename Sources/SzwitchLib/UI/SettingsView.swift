import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var showAddProfile = false
    @State private var editingProfile: GitProfile?
    
    public init() {}
    
    public var body: some View {
        TabView {
            profilesTab
                .tabItem {
                    Label("Profiles", systemImage: "person.2")
                }
            
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 500, height: 400)
        .sheet(isPresented: $showAddProfile) {
            AddProfileView()
        }
        .sheet(item: $editingProfile) { profile in
            EditProfileView(profile: profile)
        }
    }
    
    var profilesTab: some View {
        VStack(spacing: 0) {
            GitHubCLIWarningBanner()
            
            if profileManager.profiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No profiles configured")
                        .font(.title2)
                    Text("Add a GitHub account to get started.")
                        .foregroundStyle(.secondary)
                    
                    Button("Add Account") {
                        showAddProfile = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(profileManager.profiles) { profile in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(profile.name)
                                    .font(.headline)
                                Text(profile.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if profileManager.activeProfileId == profile.id {
                                Text("Active")
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundStyle(.green)
                                    .cornerRadius(4)
                            }
                            
                            Button("Edit") {
                                editingProfile = profile
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            profileManager.switchProfile(to: profile)
                        }
                        .contextMenu {
                            Button("Edit") {
                                editingProfile = profile
                            }
                            Button("Delete", role: .destructive) {
                                profileManager.removeProfile(id: profile.id)
                            }
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    HStack {
                        Spacer()
                        Button("Add Profile") {
                            showAddProfile = true
                        }
                        .buttonStyle(.bordered)
                        .padding()
                    }
                }
            }
        }
    }
    
    var generalTab: some View {
        Form {
            Section("GitHub CLI Status") {
                GitHubCLIStatusView()
            }
            
            Section("How It Works") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Szwitch uses the GitHub CLI (gh) to manage authentication.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("When you add a profile, you'll authenticate using 'gh auth login' which securely stores your credentials.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Switching profiles automatically updates your git config and GitHub CLI session.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Section("About") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.2.circle.fill")
                            .font(.title)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text("Szwitch")
                                .font(.headline)
                            Text("Version 1.0.0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("A lightweight macOS menu bar app for seamlessly switching between multiple GitHub accounts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
    }
}
