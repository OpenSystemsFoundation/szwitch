import Foundation
import SwiftUI
import os.log

/// Manages git profiles for switching between multiple GitHub accounts.
///
/// ProfileManager handles storing profiles, switching between them, and keeping track
/// of the currently active profile. It polls the system git configuration to detect
/// external changes and automatically imports new profiles.
@MainActor
public class ProfileManager: ObservableObject {
    private let logger = Logger(subsystem: "com.szwitch", category: "ProfileManager")
    @Published public var profiles: [GitProfile] = []
    @Published public var activeProfileId: UUID?
    @Published public var currentSystemName: String?
    @Published public var currentSystemEmail: String?
    @Published public var lastError: String?

    private let profilesKey = "SavedGitProfiles"
    private let activeProfileKey = "ActiveGitProfileId"
    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 5.0
    
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

        // Poll periodically to detect external changes (e.g. via terminal)
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.checkAndImportCurrentState()
            }
        }
    }
    
    /// Adds a new profile to the list of managed profiles.
    /// - Parameter profile: The profile to add
    public func addProfile(_ profile: GitProfile) {
        profiles.append(profile)
        saveProfiles()
    }

    /// Removes a profile by its ID.
    /// - Parameter id: The UUID of the profile to remove
    public func removeProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
        if activeProfileId == id {
            activeProfileId = nil
        }
        saveProfiles()
    }

    /// Updates an existing profile with new values.
    /// - Parameter updatedProfile: The updated profile data
    /// - Note: If the profile is currently active, the git configuration will be updated immediately
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

    /// Switches to a different profile, updating both git config and GitHub CLI authentication.
    /// - Parameter profile: The profile to switch to
    /// - Note: This operation is asynchronous and errors will be reported via the `lastError` property
    public func switchProfile(to profile: GitProfile) {
        // Clear any previous errors
        lastError = nil

        // Set active profile immediately
        activeProfileId = profile.id
        userDefaults.set(profile.id.uuidString, forKey: activeProfileKey)

        Task {
            do {
                // 1. Git Config - Set user name and email
                try await gitService.setGlobalConfig(name: profile.name, email: profile.email)
                logger.info("Set git config for \(profile.name)")
                
                // 2. GitHub CLI Authentication - This is the primary method
                if !profile.token.isEmpty {
                    if githubService.isInstalled() {
                        do {
                            // Switch to this account using gh CLI
                            try await githubService.switchAccount(token: profile.token, hostname: "github.com")
                            logger.info("Authenticated with gh CLI for \(profile.name)")
                        } catch {
                            logger.error("Failed to authenticate with gh CLI: \(error.localizedDescription)")
                            // This is critical - notify user
                            throw error
                        }
                    } else {
                        logger.error("GitHub CLI not installed - account switching will not work!")
                        throw GitHubError.notInstalled
                    }
                }
                
                // 3. Fetch GitHub username if missing and token exists
                var updatedProfile = profile
                if updatedProfile.githubUsername == nil && !updatedProfile.token.isEmpty {
                    do {
                        let (username, avatarUrl) = try await githubService.fetchUserInfo(hostname: "github.com")
                        updatedProfile.githubUsername = username
                        updatedProfile.avatarUrl = avatarUrl
                        
                        // Update the profile in storage
                        if let index = profiles.firstIndex(where: { $0.id == updatedProfile.id }) {
                            profiles[index] = updatedProfile
                            saveProfiles()
                        }
                        logger.info("Fetched GitHub user info: \(username)")
                    } catch {
                        logger.warning("Failed to fetch GitHub username: \(error.localizedDescription)")
                        // Continue anyway - we'll use what we have
                    }
                }

                logger.info("Successfully switched to \(updatedProfile.name)")
                logger.debug("Git operations are now authenticated as \(updatedProfile.name)")
            } catch {
                logger.error("Failed to switch profile: \(error.localizedDescription)")
                // Set user-facing error message
                await MainActor.run {
                    if let githubError = error as? GitHubError {
                        lastError = githubError.localizedDescription
                    } else {
                        lastError = "Failed to switch profile: \(error.localizedDescription)"
                    }
                }
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

        logger.debug("Checking system state: Name=\(name ?? "nil"), Email=\(email ?? "nil")")

        guard let currentEmail = email, !currentEmail.isEmpty else {
            logger.debug("No global email found.")
            // If we have profiles, we might want to unset activeProfileId if it doesn't match?
            // But let's leave it alone to avoid flickering.
            return
        }

        // Check if it matches an existing profile
        if let match = profiles.first(where: { $0.email == currentEmail }) {
            logger.debug("Matched existing profile: \(match.name)")
            if activeProfileId != match.id {
                activeProfileId = match.id
                userDefaults.set(match.id.uuidString, forKey: activeProfileKey)
            }
            return
        }

        // Import new profile
        logger.info("No match found. Importing new profile for \(currentEmail).")
        
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
        logger.info("Imported and activated: \(newProfile.name)")
    }
}
