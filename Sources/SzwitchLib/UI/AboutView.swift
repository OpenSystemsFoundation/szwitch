import SwiftUI

public struct AboutView: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            // App Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.top, 20)
            
            // App Name and Version
            VStack(spacing: 4) {
                Text("Szwitch")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Description
            Text("A lightweight macOS menu bar app for seamlessly switching between multiple GitHub accounts using the GitHub CLI.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .fixedSize(horizontal: false, vertical: true)
            
            Divider()
                .padding(.horizontal)
            
            // Info
            VStack(spacing: 12) {
                InfoRow(icon: "terminal.fill", title: "Powered by", value: "GitHub CLI (gh)")
                InfoRow(icon: "swift", title: "Built with", value: "Swift & SwiftUI")
                InfoRow(icon: "apple.logo", title: "Platform", value: "macOS 13.0+")
            }
            
            Divider()
                .padding(.horizontal)
            
            // Links
            HStack(spacing: 20) {
                Link(destination: URL(string: "https://github.com/OpenSystemsFoundation/szwitch")!) {
                    Label("GitHub", systemImage: "link.circle.fill")
                        .font(.caption)
                }
                
                Link(destination: URL(string: "https://cli.github.com")!) {
                    Label("GitHub CLI", systemImage: "terminal.fill")
                        .font(.caption)
                }
            }
            
            Spacer()
            
            // Copyright
            Text("© 2025 OpenSystemsFoundation")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 16)
        }
        .frame(width: 350, height: 480)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
        .padding(.horizontal, 40)
    }
}
