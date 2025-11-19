import Foundation

public struct GitProfile: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID = UUID()
    public var name: String
    public var email: String
    public var token: String // OAuth token or PAT
    public var avatarUrl: String?
    public var githubUsername: String? // GitHub username for credential matching
    
    public init(id: UUID = UUID(), name: String, email: String, token: String, avatarUrl: String? = nil, githubUsername: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.token = token
        self.avatarUrl = avatarUrl
        self.githubUsername = githubUsername
    }
    
    // Helper to mask token for display
    public var maskedToken: String {
        String(token.prefix(4)) + "..." + String(token.suffix(4))
    }
}
