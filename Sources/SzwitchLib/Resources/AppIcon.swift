import SwiftUI

/// Custom app icon using SF Symbols
public struct AppIcon: View {
    public init() {}
    
    public var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Icon symbol
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 60, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: 128, height: 128)
    }
}

/// Menu bar icon - a simpler version for the menu bar
public struct MenuBarIcon: View {
    public init() {}
    
    public var body: some View {
        Image(systemName: "person.2.circle")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.primary)
    }
}
