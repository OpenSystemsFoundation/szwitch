import Foundation
import SwiftUI

@MainActor
public class ProfileManager: ObservableObject {
    @Published public var profiles: [GitProfile] = []
    @Published public var activeProfileId: UUID?
    @Published public var currentSystemName: String?
    @Published public var currentSystemEmail: String?
    
    private let profilesKey = "SavedGitProfiles"
    private let activeProfileKey = "ActiveGitProfileId"
    private var pollingTimer: Timer?
    
    private let gitService: GitService
    private let githubService: GitHubServiceProtocol
    private let userDefaults: UserDefaults
    
    public init(gitService: GitService = RealGitService(), githubService: GitHubServiceProtocol = RealGitHubService(), userDefaults: UserDefaults = .standard) {
        self.gitService = gitService
        self.githubService = githubService
        self.userDefaults = userDefaults
        loadProfiles()
        startPolling()
    }
    
    private func startPolling() {
        // Check immediately
        Task { await checkAndImportCurrentState() }
        
        // Poll every 5 seconds to detect external changes (e.g. via terminal)
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.checkAndImportCurrentState()
            }
        }
    }
    
    public func addProfile(_ profile: GitProfile) {
        profiles.append(profile)
        saveProfiles()
    }
    
    public func removeProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
        if activeProfileId == id {
            activeProfileId = nil
        }
        saveProfiles()
    }
    
    public func updateProfile(_ updatedProfile: GitProfile) {
        if let index = profiles.firstIndex(where: { $0.id == updatedProfile.id }) {
            profiles[index] = updatedProfile
            saveProfiles()
            
            // If this is the active profile, update git config
            if activeProfileId == updatedProfile.id {
                switchProfile(to: updatedProfile)
            }
        }
    }
    
    public func switchProfile(to profile: GitProfile) {
        // Set active profile immediately
        activeProfileId = profile.id
        userDefaults.set(profile.id.uuidString, forKey: activeProfileKey)
        
        Task {
            do {
                // 1. Git Config - Set user name and email
                try await gitService.setGlobalConfig(name: profile.name, email: profile.email)
                print("✓ Set git config for \(profile.name)")
                
                // 2. GitHub CLI Authentication - This is the primary method
                if !profile.token.isEmpty {
                    if githubService.isInstalled() {
                        do {
                            // Switch to this account using gh CLI
                            try await githubService.switchAccount(token: profile.token, hostname: "github.com")
                            print("✓ Authenticated with gh CLI for \(profile.name)")
                        } catch {
                            print("✗ Failed to authenticate with gh CLI: \(error)")
                            // This is critical - notify user
                            throw error
                        }
                    } else {
                        print("✗ GitHub CLI not installed - account switching will not work!")
                        throw GitHubError.notInstalled
                    }
                }
                
                // 3. Fetch GitHub username if missing and token exists
                var updatedProfile = profile
                if updatedProfile.githubUsername == nil && !updatedProfile.token.isEmpty {
                    do {
                        let oauthManager = OAuthManager()
                        let (username, avatarUrl) = try await oauthManager.fetchGitHubUser(token: updatedProfile.token)
                        updatedProfile.githubUsername = username
                        updatedProfile.avatarUrl = avatarUrl
                        
                        // Update the profile in storage
                        if let index = profiles.firstIndex(where: { $0.id == updatedProfile.id }) {
                            profiles[index] = updatedProfile
                            saveProfiles()
                        }
                        print("✓ Fetched GitHub user info: \(username)")
                    } catch {
                        print("⚠ Failed to fetch GitHub username: \(error)")
                        // Continue anyway - we'll use what we have
                    }
                }
                
                print("✓ Successfully switched to \(updatedProfile.name)")
                print("  You can now use git push/pull and all GitHub operations as \(updatedProfile.name)")
            } catch {
                print("✗ Failed to switch profile: \(error)")
                // TODO: Show user-facing error message
            }
        }
    }
    
    private func loadProfiles() {
        if let data = userDefaults.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([GitProfile].self, from: data) {
            self.profiles = decoded
        }
        
        if let idString = userDefaults.string(forKey: activeProfileKey),
           let id = UUID(uuidString: idString) {
            self.activeProfileId = id
        }
    }
    
    private func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(profiles) {
            userDefaults.set(encoded, forKey: profilesKey)
        }
    }
    
    public func checkAndImportCurrentState() async {
        let (name, email) = await gitService.getCurrentConfig()
        
        // Update published state for UI
        self.currentSystemName = name
        self.currentSystemEmail = email
        
        print("Checking system state: Name=\(name ?? "nil"), Email=\(email ?? "nil")")
        
        guard let currentEmail = email, !currentEmail.isEmpty else {
            print("No global email found.")
            // If we have profiles, we might want to unset activeProfileId if it doesn't match?
            // But let's leave it alone to avoid flickering.
            return
        }
        
        // Check if it matches an existing profile
        if let match = profiles.first(where: { $0.email == currentEmail }) {
            print("Matched existing profile: \(match.name)")
            if activeProfileId != match.id {
                activeProfileId = match.id
                userDefaults.set(match.id.uuidString, forKey: activeProfileKey)
            }
            return
        }
        
        // Import new profile
        print("No match found. Importing new profile for \(currentEmail).")
        
        var token = ""
        // Try to read token from Keychain
        if let data = KeychainHelper.shared.read(service: "github.com", account: "git"),
           let t = String(data: data, encoding: .utf8) {
            token = t
        } else if let data = KeychainHelper.shared.read(service: "https://github.com", account: "git"),
                  let t = String(data: data, encoding: .utf8) {
            token = t
        }
        
        let newProfile = GitProfile(
            name: name ?? currentEmail, // Use email as name if name is missing
            email: currentEmail,
            token: token
        )
        
        addProfile(newProfile)
        activeProfileId = newProfile.id
        userDefaults.set(newProfile.id.uuidString, forKey: activeProfileKey)
        print("Imported and activated: \(newProfile.name)")
    }
}
