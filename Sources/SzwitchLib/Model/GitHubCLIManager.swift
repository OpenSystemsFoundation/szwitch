import Foundation
import SwiftUI

/// Manages GitHub CLI installation status and provides installation support
@MainActor
public class GitHubCLIManager: ObservableObject {
    @Published public var installStatus: GitHubInstallStatus = .notInstalled
    @Published public var isInstalling: Bool = false
    @Published public var installError: String?
    
    private let githubService: GitHubServiceProtocol
    
    public init(githubService: GitHubServiceProtocol = RealGitHubService()) {
        self.githubService = githubService
        checkInstallation()
    }
    
    public func checkInstallation() {
        installStatus = githubService.getInstallationStatus()
    }
    
    public func installGitHubCLI() async {
        guard installStatus != .installed else { return }
        
        isInstalling = true
        installError = nil
        
        do {
            try await githubService.install()
            checkInstallation()
            isInstalling = false
        } catch {
            installError = error.localizedDescription
            isInstalling = false
        }
    }
    
    public var statusMessage: String {
        switch installStatus {
        case .installed:
            return "GitHub CLI is installed and ready"
        case .notInstalled:
            return "GitHub CLI is not installed"
        case .brewNotFound:
            return "Homebrew not found - required to install GitHub CLI"
        }
    }
    
    public var canInstall: Bool {
        switch installStatus {
        case .notInstalled:
            return true
        case .installed, .brewNotFound:
            return false
        }
    }
}
