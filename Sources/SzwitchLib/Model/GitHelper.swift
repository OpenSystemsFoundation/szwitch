import Foundation

import Foundation

public protocol GitService: Sendable {
    func setGlobalConfig(name: String, email: String) async throws
    func getCurrentConfig() async -> (name: String?, email: String?)
}

public struct RealGitService: GitService {
    public init() {}
    
    public static let gitPath: String = {
        let paths = [
            "/opt/homebrew/bin/git",
            "/usr/local/bin/git",
            "/usr/bin/git",
            "/bin/git"
        ]
        return paths.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? "/usr/bin/git"
    }()
    
    private static func run(_ args: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: RealGitService.gitPath)
                    process.arguments = args
                    
                    let pipe = Pipe()
                    process.standardOutput = pipe
                    process.standardError = pipe
                    
                    try process.run()
                    process.waitUntilExit()
                    
                    if process.terminationStatus != 0 {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: data, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: GitError.commandFailed(output))
                    } else {
                        continuation.resume()
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func setGlobalConfig(name: String, email: String) async throws {
        try await RealGitService.run(["config", "--global", "user.name", name])
        try await RealGitService.run(["config", "--global", "user.email", email])
    }
    
    public func getCurrentConfig() async -> (name: String?, email: String?) {
        async let name = try? RealGitService.runCapture(["config", "--global", "user.name"])
        async let email = try? RealGitService.runCapture(["config", "--global", "user.email"])
        return await (name?.trimmingCharacters(in: .whitespacesAndNewlines), 
                      email?.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    private static func runCapture(_ args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: RealGitService.gitPath)
                    process.arguments = args
                    
                    let pipe = Pipe()
                    process.standardOutput = pipe
                    
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// Backward compatibility for static access if needed, or just remove
public struct GitHelper {
    public static let shared: GitService = RealGitService()
}

public enum GitError: Error {
    case commandFailed(String)
}
