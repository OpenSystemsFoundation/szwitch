import Foundation
import SwiftUI

@MainActor
public class OAuthManager: ObservableObject {
    @Published public var state: OAuthState = .idle
    @Published public var userCode: String?
    @Published public var verificationUri: URL?
    @Published public var clientId: String {
        didSet {
            UserDefaults.standard.set(clientId, forKey: "GitHubClientID")
        }
    }
    
    private var deviceCode: String?
    private var pollingInterval: Double = 5.0
    private var pollingTimer: Timer?
    
    public init() {
        self.clientId = UserDefaults.standard.string(forKey: "GitHubClientID") ?? ""
    }
    
    public func startDeviceFlow() async {
        guard !clientId.isEmpty else {
            print("Client ID is missing")
            state = .error("Client ID is missing")
            return
        }
        
        state = .loading
        
        let url = URL(string: "https://github.com/login/device/code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["client_id": clientId, "scope": "repo user"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
            
            self.deviceCode = response.device_code
            self.userCode = response.user_code
            self.verificationUri = URL(string: response.verification_uri)
            self.pollingInterval = Double(response.interval)
            self.state = .waitingForAuth
            
            startPolling()
            
        } catch {
            print("Error starting device flow: \(error)")
            state = .error(error.localizedDescription)
        }
    }
    
    private func startPolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.pollForToken()
            }
        }
    }
    
    private func pollForToken() async {
        guard let deviceCode = deviceCode else { return }
        
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "client_id": clientId,
            "device_code": deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            // GitHub returns 200 OK even for errors like "authorization_pending"
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let error = json["error"] as? String {
                    if error == "authorization_pending" {
                        // Keep polling
                        return
                    } else if error == "slow_down" {
                        // Increase interval (simplified: just add 5s)
                        pollingTimer?.invalidate()
                        pollingInterval += 5.0
                        startPolling()
                        return
                    } else {
                        // Real error or expired
                        stopPolling()
                        state = .error(error)
                        return
                    }
                }
                
                if let accessToken = json["access_token"] as? String {
                    stopPolling()
                    // Success!
                    // In a real app, we'd fetch the user profile now.
                    // For now, just print it and set state.
                    print("Got token: \(accessToken)")
                    state = .authenticated(accessToken)
                }
            }
        } catch {
            print("Polling error: \(error)")
        }
    }
    
    public func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // MARK: - GitHub User Info
    
    /// Fetch GitHub user information using an access token
    /// - Parameter token: The GitHub OAuth access token
    /// - Returns: A tuple containing the username and avatar URL
    public func fetchGitHubUser(token: String) async throws -> (username: String, avatarUrl: String?) {
        let url = URL(string: "https://api.github.com/user")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GitHubAPIError.unauthorized
        }
        
        let userInfo = try JSONDecoder().decode(GitHubUser.self, from: data)
        return (username: userInfo.login, avatarUrl: userInfo.avatar_url)
    }
}

public enum OAuthState: Equatable {
    case idle
    case loading
    case waitingForAuth
    case authenticated(String)
    case error(String)
}

struct DeviceCodeResponse: Decodable {
    let device_code: String
    let user_code: String
    let verification_uri: String
    let expires_in: Int
    let interval: Int
}

struct GitHubUser: Decodable {
    let login: String
    let avatar_url: String?
}

public enum GitHubAPIError: Error {
    case unauthorized
}
