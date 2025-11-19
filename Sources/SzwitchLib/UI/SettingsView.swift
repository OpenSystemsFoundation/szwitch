import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var showAddProfile = false
    @State private var editingProfile: GitProfile?
    @AppStorage("GitHubClientID") private var clientId: String = ""
    
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
            
            Section("GitHub App Configuration") {
                HStack {
                    TextField("Client ID", text: $clientId)
                    if !clientId.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                
                Text("Saved automatically")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                DisclosureGroup("How to get a Client ID") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. Go to GitHub Settings > Developer settings > OAuth Apps.")
                        Text("2. Click 'New OAuth App'.")
                        Text("3. Set **Authorization callback URL** to: `http://localhost`")
                        Text("4. **IMPORTANT**: Check **Enable Device Flow**.")
                        Text("5. Register and copy the **Client ID** above.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                }
            }
            
            Section("About") {
                Text("Szwitch v1.0")
                Text("A lightweight GitHub account switcher.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
