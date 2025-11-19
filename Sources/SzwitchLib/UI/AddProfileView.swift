import SwiftUI

public struct AddProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var profileManager: ProfileManager
    @StateObject private var oauthManager = OAuthManager()
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var token: String = ""
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Add New Profile")
                .font(.headline)
            
            Form {
                Section("Authentication") {
                    if case .authenticated(let t) = oauthManager.state {
                        Text("Authenticated!")
                            .foregroundStyle(.green)
                        Text("Token: \(String(t.prefix(8)))...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        if oauthManager.clientId.isEmpty {
                            TextField("Client ID", text: $oauthManager.clientId)
                        }
                        
                        if case .waitingForAuth = oauthManager.state {
                            VStack(alignment: .leading) {
                                Text("Code: \(oauthManager.userCode ?? "")")
                                    .font(.monospacedDigit(.body)())
                                    .textSelection(.enabled)
                                
                                if let url = oauthManager.verificationUri {
                                    Link("Open GitHub", destination: url)
                                }
                            }
                        } else {
                            Button("Login with GitHub") {
                                Task { await oauthManager.startDeviceFlow() }
                            }
                        }
                    }
                }
                
                Section("Profile Details") {
                    TextField("Name (e.g. John Doe)", text: $name)
                    TextField("Email (e.g. john@example.com)", text: $email)
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    let t = (oauthManager.state.token ?? token)
                    let profile = GitProfile(name: name, email: email, token: t)
                    profileManager.addProfile(profile)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || email.isEmpty || (oauthManager.state.token == nil && token.isEmpty))
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 350, height: 450)
        .onChange(of: oauthManager.state) { newState in
            if case .authenticated(let t) = newState {
                self.token = t
                // In a real app, we would fetch user details here
            }
        }
    }
}

extension OAuthState {
    var token: String? {
        if case .authenticated(let t) = self { return t }
        return nil
    }
}
