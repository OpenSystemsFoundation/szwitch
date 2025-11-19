import SwiftUI

public struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var profileManager: ProfileManager
    
    let profile: GitProfile
    @State private var name: String
    @State private var email: String
    @State private var token: String
    @State private var githubUsername: String?
    @State private var avatarUrl: String?
    @State private var showingDeleteConfirmation = false
    @State private var isAuthenticating = false
    @State private var authError: String?
    @State private var cliOutput: String = ""
    @State private var showCLIOutput = false
    
    public init(profile: GitProfile) {
        self.profile = profile
        _name = State(initialValue: profile.name)
        _email = State(initialValue: profile.email)
        _token = State(initialValue: profile.token)
        _githubUsername = State(initialValue: profile.githubUsername)
        _avatarUrl = State(initialValue: profile.avatarUrl)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header with top padding
            Text("Edit Profile")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 24)
                .padding(.bottom, 16)
            
            Form {
                Section("Profile Details") {
                    TextField("Name", text: $name)
                        .disabled(isAuthenticating)
                    TextField("Email", text: $email)
                        .disabled(isAuthenticating)
                }
                
                Section("GitHub Authentication") {
                    if !token.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Authenticated as @\(githubUsername ?? "user")")
                                    .foregroundStyle(.primary)
                                Text("Account is linked")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Re-authenticate") {
                                authenticateWithGitHubCLI()
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.blue)
                        }
                        .padding(.vertical, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No GitHub account linked")
                                .foregroundStyle(.secondary)
                            
                            if isAuthenticating {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Authenticating...")
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Button(action: authenticateWithGitHubCLI) {
                                    HStack {
                                        Image(systemName: "key.fill")
                                        Text("Authenticate with GitHub")
                                    }
                                }
                                .buttonStyle(.bordered)
                                
                                if let error = authError {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                            
                            Text("GitHub CLI will open your browser to authenticate securely.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    // CLI Output Section
                    if showCLIOutput {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Authentication Output")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button(action: { cliOutput = ""; showCLIOutput = false }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            CLIOutputView(output: cliOutput)
                                .frame(height: 120)
                        }
                    }
                }
                
                Section {
                    Button("Delete Profile", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                    .disabled(isAuthenticating)
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save Changes") {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || email.isEmpty || isAuthenticating)
            }
            .padding()
        }
        .frame(width: 550, height: showCLIOutput ? 600 : 500)
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
    
    private func authenticateWithGitHubCLI() {
        isAuthenticating = true
        authError = nil
        showCLIOutput = true
        cliOutput = "Starting GitHub authentication...\n"
        
        Task {
            do {
                let githubService = RealGitHubService()
                
                cliOutput += "Running: gh auth login --hostname github.com --web\n"
                cliOutput += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                
                // Run gh auth login with web authentication
                try await githubService.interactiveLogin(hostname: "github.com") { output in
                    Task { @MainActor in
                        cliOutput += output
                    }
                }
                
                // Give it a moment to complete
                try await Task.sleep(nanoseconds: 500_000_000)
                
                cliOutput += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                cliOutput += "✓ Authentication successful!\n"
                cliOutput += "Fetching user information...\n"
                
                // Fetch user info
                let (username, avatar) = try await githubService.fetchUserInfo(hostname: "github.com")
                
                cliOutput += "✓ Logged in as @\(username)\n"
                
                // Get the auth token
                let authToken = try await githubService.getAuthToken(hostname: "github.com")
                
                await MainActor.run {
                    token = authToken
                    githubUsername = username
                    avatarUrl = avatar
                    isAuthenticating = false
                    authError = nil
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    authError = error.localizedDescription
                    cliOutput += "\n✗ Error: \(error.localizedDescription)\n"
                }
            }
        }
    }
    
    private func saveChanges() {
        var updatedProfile = GitProfile(
            id: profile.id,
            name: name,
            email: email,
            token: token
        )
        updatedProfile.githubUsername = githubUsername
        updatedProfile.avatarUrl = avatarUrl
        profileManager.updateProfile(updatedProfile)
        dismiss()
    }
}
