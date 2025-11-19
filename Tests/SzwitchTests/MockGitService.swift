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
