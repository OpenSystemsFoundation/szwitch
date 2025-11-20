import Foundation
import os.log

/// Protocol for interacting with GitHub CLI and GitHub API.
/// Provides methods for authentication, account management, and user information retrieval.
public protocol GitHubServiceProtocol: Sendable {
    /// Checks if GitHub CLI (gh) is installed on the system.
    /// - Returns: `true` if gh is installed, `false` otherwise
    func isInstalled() -> Bool

    /// Installs GitHub CLI using Homebrew.
    /// - Throws: `GitHubError.brewNotFound` if Homebrew is not installed
    func install() async throws

    /// Logs in to GitHub using a personal access token.
    /// - Parameters:
    ///   - token: The GitHub personal access token
    ///   - hostname: The GitHub hostname (default: "github.com")
    /// - Throws: `GitHubError.notInstalled` if gh is not installed
    func login(token: String, hostname: String) async throws

    /// Performs interactive web-based login to GitHub.
    /// - Parameters:
    ///   - hostname: The GitHub hostname (default: "github.com")
    ///   - outputHandler: Callback that receives real-time output from the login process
    /// - Throws: `GitHubError.notInstalled` if gh is not installed
    func interactiveLogin(hostname: String, outputHandler: @escaping @Sendable (String) -> Void)
        async throws

    /// Logs out from GitHub.
    /// - Parameter hostname: The GitHub hostname (default: "github.com")
    /// - Throws: `GitHubError.notInstalled` if gh is not installed
    func logout(hostname: String) async throws

    /// Configures git to use GitHub CLI as the credential helper.
    /// - Throws: `GitHubError.notInstalled` if gh is not installed
    func setupGit() async throws

    /// Gets the currently authenticated GitHub username.
    /// - Parameter hostname: The GitHub hostname (default: "github.com")
    /// - Returns: The username if authenticated, `nil` otherwise
    func getCurrentUser(hostname: String) async -> String?

    /// Switches to a different GitHub account using the provided token.
    /// - Parameters:
    ///   - token: The GitHub personal access token for the account
    ///   - hostname: The GitHub hostname (default: "github.com")
    /// - Throws: `GitHubError` if the switch fails
    func switchAccount(token: String, hostname: String) async throws

    /// Gets the current installation status of GitHub CLI.
    /// - Returns: The installation status
    func getInstallationStatus() -> GitHubInstallStatus

    /// Fetches user information from GitHub API.
    /// - Parameter hostname: The GitHub hostname (default: "github.com")
    /// - Returns: A tuple containing the username and optional avatar URL
    /// - Throws: `GitHubError` if the fetch fails
    func fetchUserInfo(hostname: String) async throws -> (username: String, avatarUrl: String?)

    /// Gets the authentication token for the currently logged-in user.
    /// - Parameter hostname: The GitHub hostname (default: "github.com")
    /// - Returns: The authentication token
    /// - Throws: `GitHubError` if no token is found
    func getAuthToken(hostname: String) async throws -> String
}

public enum GitHubInstallStatus {
    case installed
    case notInstalled
    case brewNotFound
}

public struct RealGitHubService: GitHubServiceProtocol {
    private let logger = Logger(subsystem: "com.szwitch", category: "GitHubService")

    public init() {}

    /// Helper function to find an executable in common paths or using `which`
    private static func findExecutable(name: String, commonPaths: [String]) -> String? {
        // First check common installation paths
        if let found = commonPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            return found
        }

        // Fallback: try to find it in PATH using `which`
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(
                in: .whitespacesAndNewlines),
                !path.isEmpty
            {
                return path
            }
        }
        return nil
    }

    public static let ghPath: String? = findExecutable(
        name: "gh",
        commonPaths: [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh",
            "/bin/gh",
        ]
    )

    public static let brewPath: String? = findExecutable(
        name: "brew",
        commonPaths: [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
            "/usr/bin/brew",
            "/bin/brew",
        ]
    )

    private static func run(_ args: [String], executable: String, stdinData: Data? = nil)
        async throws -> String
    {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<String, Error>) in
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

        guard let tokenData = token.data(using: .utf8) else {
            throw GitHubError.commandFailed("Invalid token encoding")
        }
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
            if let range = output.range(
                of: "Logged in to .* as ([^ ]+)", options: .regularExpression),
                let match = output[range].firstMatch(of: /Logged in to .* as ([^ ]+)/)
            {
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
                    let match = line[range].firstMatch(of: /account ([^ ]+)/)
                {
                    return String(match.1)
                }
                return nil
            }

        logger.debug("Found accounts: \(accounts)")

        // Get username for the provided token by calling GitHub API with it
        let username = try await fetchUsernameFromToken(token: token, hostname: hostname)
        logger.debug("Token belongs to: \(username)")

        // Check if this account is already logged in
        if accounts.contains(username) {
            logger.info("Account \(username) already exists, switching to it")
            // Use gh auth switch
            _ = try await RealGitHubService.run(
                ["auth", "switch", "--hostname", hostname, "--user", username],
                executable: ghPath
            )
        } else {
            logger.info("Account \(username) doesn't exist, logging in")
            // Login with new token
            try await login(token: token, hostname: hostname)
        }

        // Setup git credential helper
        try await setupGit()
    }

    private func fetchUsernameFromToken(token: String, hostname: String = "github.com") async throws
        -> String
    {
        // Make a direct API call with the token to get the username
        guard let url = URL(string: "https://api.\(hostname)/user") else {
            throw GitHubError.commandFailed("Invalid GitHub API URL for hostname: \(hostname)")
        }
        var request = URLRequest(url: url)
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.commandFailed("Invalid response from GitHub API")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage: String
            if let errorBody = String(data: data, encoding: .utf8) {
                errorMessage = "GitHub API returned status \(httpResponse.statusCode): \(errorBody)"
            } else {
                errorMessage = "GitHub API returned status \(httpResponse.statusCode)"
            }
            throw GitHubError.commandFailed(errorMessage)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GitHubError.commandFailed("Failed to parse JSON response from GitHub API")
        }

        guard let username = json["login"] as? String else {
            throw GitHubError.commandFailed("GitHub API response missing 'login' field")
        }

        return username
    }

    public func fetchUserInfo(hostname: String = "github.com") async throws -> (
        username: String, avatarUrl: String?
    ) {
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
            let username = json["login"] as? String
        else {
            throw GitHubError.commandFailed("Failed to parse user info")
        }

        let avatarUrl = json["avatar_url"] as? String
        return (username: username, avatarUrl: avatarUrl)
    }

    public func interactiveLogin(
        hostname: String = "github.com", outputHandler: @escaping @Sendable (String) -> Void
    ) async throws {
        guard let ghPath = RealGitHubService.ghPath else {
            throw GitHubError.notInstalled
        }

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
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
                        let errorMessage =
                            String(data: errorData, encoding: .utf8) ?? "Authentication failed"
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
