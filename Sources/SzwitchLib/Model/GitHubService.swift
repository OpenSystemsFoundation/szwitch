import Foundation

public protocol GitHubServiceProtocol: Sendable {
    func isInstalled() -> Bool
    func install() async throws
    func login(token: String, hostname: String) async throws
    func interactiveLogin(hostname: String, outputHandler: @escaping @Sendable (String) -> Void) async throws
    func logout(hostname: String) async throws
    func setupGit() async throws
    func getCurrentUser(hostname: String) async -> String?
    func switchAccount(token: String, hostname: String) async throws
    func getInstallationStatus() -> GitHubInstallStatus
    func fetchUserInfo(hostname: String) async throws -> (username: String, avatarUrl: String?)
    func getAuthToken(hostname: String) async throws -> String
}

public enum GitHubInstallStatus {
    case installed
    case notInstalled
    case brewNotFound
}

public struct RealGitHubService: GitHubServiceProtocol {
    public init() {}
    
    public static let ghPath: String? = {
        let paths = [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh",
            "/bin/gh"
        ]
        if let found = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            return found
        }
        // Fallback: try to find it in PATH using `which`
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["gh"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        }
        return nil
    }()
    
    public static let brewPath: String? = {
        let paths = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
            "/usr/bin/brew",
            "/bin/brew"
        ]
        if let found = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            return found
        }
        // Fallback: try to find it in PATH using `which`
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["brew"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        }
        return nil
    }()
    
    private static func run(_ args: [String], executable: String, stdinData: Data? = nil) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: executable)
                    process.arguments = args
                    
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    
                    if let stdinData = stdinData {
                        let inputPipe = Pipe()
                        process.standardInput = inputPipe
                        inputPipe.fileHandleForWriting.write(stdinData)
                        inputPipe.fileHandleForWriting.closeFile()
                    }
                    
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe
                    
                    try process.run()
                    process.waitUntilExit()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    
                    if process.terminationStatus != 0 {
                        let errorMessage = error.isEmpty ? output : error
                        continuation.resume(throwing: GitHubError.commandFailed(errorMessage))
                    } else {
                        continuation.resume(returning: output)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func isInstalled() -> Bool {
        return RealGitHubService.ghPath != nil
    }
    
    public func getInstallationStatus() -> GitHubInstallStatus {
        if isInstalled() {
            return .installed
        }
        if RealGitHubService.brewPath != nil {
            return .notInstalled
        }
        return .brewNotFound
    }
    
    public func install() async throws {
        guard let brewPath = RealGitHubService.brewPath else {
            throw GitHubError.brewNotFound
        }
        _ = try await RealGitHubService.run(["install", "gh"], executable: brewPath)
        // Verify installation
        guard isInstalled() else {
            throw GitHubError.installationFailed
        }
    }
    
    public func login(token: String, hostname: String = "github.com") async throws {
        guard let ghPath = RealGitHubService.ghPath else {
            throw GitHubError.notInstalled
        }
        
        let tokenData = token.data(using: .utf8)!
        _ = try await RealGitHubService.run(
            ["auth", "login", "--with-token", "--hostname", hostname],
            executable: ghPath,
            stdinData: tokenData
        )
    }
    
    public func logout(hostname: String = "github.com") async throws {
        guard let ghPath = RealGitHubService.ghPath else {
            throw GitHubError.notInstalled
        }
        
        _ = try await RealGitHubService.run(
            ["auth", "logout", "--hostname", hostname],
            executable: ghPath
        )
    }
    
    public func setupGit() async throws {
        guard let ghPath = RealGitHubService.ghPath else {
            throw GitHubError.notInstalled
        }
        
        _ = try await RealGitHubService.run(["auth", "setup-git"], executable: ghPath)
    }
    
    public func getCurrentUser(hostname: String = "github.com") async -> String? {
        guard let ghPath = RealGitHubService.ghPath else {
            return nil
        }
        
        do {
            let output = try await RealGitHubService.run(
                ["auth", "status", "--hostname", hostname],
                executable: ghPath
            )
            // Parse output to find username
            // Output looks like: "Logged in to github.com as username (oauth_token)"
            if let range = output.range(of: "Logged in to .* as ([^ ]+)", options: .regularExpression),
               let match = output[range].firstMatch(of: /Logged in to .* as ([^ ]+)/) {
                return String(match.1)
            }
            return nil
        } catch {
            return nil
        }
    }
    
    public func switchAccount(token: String, hostname: String = "github.com") async throws {
        guard let ghPath = RealGitHubService.ghPath else {
            throw GitHubError.notInstalled
        }
        
        // First, try to get the username for this token
        // We need to check if this account already exists in gh
        let tokenData = token.data(using: .utf8)!
        
        // Try to get username by temporarily authenticating
        // gh stores multiple accounts, so we should check if account exists first
        let output = try await RealGitHubService.run(
            ["auth", "status", "--hostname", hostname],
            executable: ghPath
        )
        
        // Parse all logged in accounts
        // Look for: "✓ Logged in to github.com account USERNAME"
        let accounts = output.components(separatedBy: "\n")
            .filter { $0.contains("Logged in to \(hostname) account") }
            .compactMap { line -> String? in
                if let range = line.range(of: "account ([^ ]+)", options: .regularExpression),
                   let match = line[range].firstMatch(of: /account ([^ ]+)/) {
                    return String(match.1)
                }
                return nil
            }
        
        print("Found accounts: \(accounts)")
        
        // Get username for the provided token by calling GitHub API with it
        let username = try await fetchUsernameFromToken(token: token, hostname: hostname)
        print("Token belongs to: \(username)")
        
        // Check if this account is already logged in
        if accounts.contains(username) {
            print("Account \(username) already exists, switching to it")
            // Use gh auth switch
            _ = try await RealGitHubService.run(
                ["auth", "switch", "--hostname", hostname, "--user", username],
                executable: ghPath
            )
        } else {
            print("Account \(username) doesn't exist, logging in")
            // Login with new token
            try await login(token: token, hostname: hostname)
        }
        
        // Setup git credential helper
        try await setupGit()
    }
    
    private func fetchUsernameFromToken(token: String, hostname: String = "github.com") async throws -> String {
        // Make a direct API call with the token to get the username
        let url = URL(string: "https://api.\(hostname)/user")!
        var request = URLRequest(url: url)
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GitHubError.commandFailed("Failed to fetch user info from token")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let username = json["login"] as? String else {
            throw GitHubError.commandFailed("Failed to parse username from API response")
        }
        
        return username
    }
    
    public func fetchUserInfo(hostname: String = "github.com") async throws -> (username: String, avatarUrl: String?) {
        guard let ghPath = RealGitHubService.ghPath else {
            throw GitHubError.notInstalled
        }
        
        // Use gh api to call the GitHub API
        let output = try await RealGitHubService.run(
            ["api", "user", "--hostname", hostname],
            executable: ghPath
        )
        
        // Parse JSON response
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let username = json["login"] as? String else {
            throw GitHubError.commandFailed("Failed to parse user info")
        }
        
        let avatarUrl = json["avatar_url"] as? String
        return (username: username, avatarUrl: avatarUrl)
    }
    
    public func interactiveLogin(hostname: String = "github.com", outputHandler: @escaping @Sendable (String) -> Void) async throws {
        guard let ghPath = RealGitHubService.ghPath else {
            throw GitHubError.notInstalled
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: ghPath)
                    process.arguments = ["auth", "login", "--hostname", hostname, "--web"]
                    
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe
                    
                    // Stream output in real-time
                    outputPipe.fileHandleForReading.readabilityHandler = { handle in
                        let data = handle.availableData
                        if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                            outputHandler(str)
                        }
                    }
                    
                    errorPipe.fileHandleForReading.readabilityHandler = { handle in
                        let data = handle.availableData
                        if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                            outputHandler(str)
                        }
                    }
                    
                    try process.run()
                    process.waitUntilExit()
                    
                    // Clean up handlers
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    
                    if process.terminationStatus != 0 {
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Authentication failed"
                        continuation.resume(throwing: GitHubError.commandFailed(errorMessage))
                    } else {
                        continuation.resume(returning: ())
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func getAuthToken(hostname: String = "github.com") async throws -> String {
        guard let ghPath = RealGitHubService.ghPath else {
            throw GitHubError.notInstalled
        }
        
        let output = try await RealGitHubService.run(
            ["auth", "token", "--hostname", hostname],
            executable: ghPath
        )
        
        let token = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw GitHubError.commandFailed("No authentication token found")
        }
        
        return token
    }
}

public enum GitHubError: Error {
    case commandFailed(String)
    case brewNotFound
    case notInstalled
    case installationFailed
    
    public var localizedDescription: String {
        switch self {
        case .commandFailed(let message):
            return "Command failed: \(message)"
        case .brewNotFound:
            return "Homebrew not found. Please install Homebrew first from https://brew.sh"
        case .notInstalled:
            return "GitHub CLI (gh) is not installed"
        case .installationFailed:
            return "Failed to install GitHub CLI"
        }
    }
}
