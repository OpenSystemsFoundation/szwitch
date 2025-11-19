import SwiftUI

public struct AddProfileView: View {
    @Environment(\.dismiss) private var dismiss: DismissAction
    @EnvironmentObject var profileManager: ProfileManager
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var token: String = ""
    @State private var isAuthenticating = false
    @State private var authError: String?
    @State private var githubUsername: String?
    @State private var avatarUrl: String?
    @State private var cliOutput: String = ""
    @State private var showCLIOutput = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header with top padding
            Text("Add New Profile")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 24)
                .padding(.bottom, 16)
            
            Form {
                Section("GitHub Authentication") {
                    if !token.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Authenticated as @\(githubUsername ?? "user")")
                                    .foregroundStyle(.primary)
                                Text("Ready to create profile")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
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
                
                Section("Profile Details") {
                    TextField("Name (e.g. John Doe)", text: $name)
                        .disabled(isAuthenticating)
                    TextField("Email (e.g. john@example.com)", text: $email)
                        .disabled(isAuthenticating)
                }
            }
            .formStyle(.grouped)
            
            // Footer buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save Profile") {
                    saveProfile()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || email.isEmpty || token.isEmpty || isAuthenticating)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 550, height: showCLIOutput ? 600 : 480)
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
    
    private func saveProfile() {
        var profile = GitProfile(name: name, email: email, token: token)
        profile.githubUsername = githubUsername
        profile.avatarUrl = avatarUrl
        profileManager.addProfile(profile)
        dismiss()
    }
}
