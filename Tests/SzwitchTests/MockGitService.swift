import Foundation
@testable import SzwitchLib

actor MockGitService: GitService {
    private var config: [String: String] = [:]
    
    func setGlobalConfig(name: String, email: String) async throws {
        config["user.name"] = name
        config["user.email"] = email
    }
    
    func getCurrentConfig() async -> (name: String?, email: String?) {
        return (config["user.name"], config["user.email"])
    }
    
    // Helper for tests to setup state
    func setConfig(name: String?, email: String?) {
        if let name = name { config["user.name"] = name }
        if let email = email { config["user.email"] = email }
    }
}

struct MockGitHubService: GitHubServiceProtocol {
    func isInstalled() -> Bool { return true }
    func install() async throws {}
    func login(token: String, hostname: String) async throws {}
    func interactiveLogin(hostname: String, outputHandler: @escaping @Sendable (String) -> Void) async throws {
        outputHandler("Mock authentication output\n")
    }
    func logout(hostname: String) async throws {}
    func setupGit() async throws {}
    func getCurrentUser(hostname: String) async -> String? { return "testuser" }
    func switchAccount(token: String, hostname: String) async throws {}
    func getInstallationStatus() -> GitHubInstallStatus { return .installed }
    func fetchUserInfo(hostname: String) async throws -> (username: String, avatarUrl: String?) {
        return ("testuser", "https://avatars.githubusercontent.com/u/12345")
    }
    func getAuthToken(hostname: String) async throws -> String {
        return "gho_mocktoken123456789"
    }
}
