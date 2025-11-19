import Foundation

public protocol GitHubServiceProtocol: Sendable {
    func isInstalled() -> Bool
    func install() async throws
    func login(token: String, hostname: String) async throws
    func logout(hostname: String) async throws
    func setupGit() async throws
    func getCurrentUser(hostname: String) async -> String?
    func switchAccount(token: String, hostname: String) async throws
    func getInstallationStatus() -> GitHubInstallStatus
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
        // First logout current account
        do {
            try await logout(hostname: hostname)
        } catch {
            // Ignore logout errors - might not be logged in
            print("Logout error (ignoring): \(error)")
        }
        
        // Login with new token
        try await login(token: token, hostname: hostname)
        
        // Setup git credential helper
        try await setupGit()
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
