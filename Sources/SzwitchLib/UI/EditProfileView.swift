import SwiftUI

public struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var profileManager: ProfileManager
    @StateObject private var oauthManager = OAuthManager()
    @AppStorage("GitHubClientID") private var clientId: String = ""
    
    let profile: GitProfile
    @State private var name: String
    @State private var email: String
    @State private var token: String
    
    @State private var showingDeleteConfirmation = false
    
    public init(profile: GitProfile) {
        self.profile = profile
        _name = State(initialValue: profile.name)
        _email = State(initialValue: profile.email)
        _token = State(initialValue: profile.token)
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Edit Profile")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top)
            
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                }
                
                Section("GitHub Authentication") {
                    if token.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No token linked")
                                .foregroundStyle(.secondary)
                            
                            switch oauthManager.state {
                            case .waitingForAuth:
                                if let userCode = oauthManager.userCode {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Enter this code on GitHub:")
                                            .font(.caption)
                                        Text(userCode)
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .textSelection(.enabled)
                                        if let uri = oauthManager.verificationUri {
                                            Button("Open GitHub") {
                                                NSWorkspace.shared.open(uri)
                                            }
                                            .buttonStyle(.link)
                                        }
                                    }
                                }
                            case .loading:
                                ProgressView("Authenticating...")
                            default:
                                Button("Link GitHub Account") {
                                    Task {
                                        await oauthManager.startDeviceFlow()
                                    }
                                }
                                .disabled(clientId.isEmpty)
                            }
                        }
                    } else {
                        HStack {
                            Text("Token: ••••••••")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Re-authenticate") {
                                Task {
                                    await oauthManager.startDeviceFlow()
                                }
                            }
                            .buttonStyle(.link)
                            .disabled(clientId.isEmpty)
                        }
                    }
                }
                
                Section {
                    Button("Delete Profile", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    saveChanges()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || email.isEmpty)
            }
            .padding()
        }
        .frame(width: 450, height: 450)
        .onReceive(oauthManager.$state) { newState in
            if case .authenticated(let newToken) = newState {
                token = newToken
            }
        }
        .confirmationDialog("Delete Profile?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                profileManager.removeProfile(id: profile.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this profile? This action cannot be undone.")
        }
    }
    
    private func saveChanges() {
        let updatedProfile = GitProfile(
            id: profile.id,
            name: name,
            email: email,
            token: token
        )
        profileManager.updateProfile(updatedProfile)
        dismiss()
    }
}
