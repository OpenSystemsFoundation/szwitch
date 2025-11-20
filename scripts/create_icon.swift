#!/usr/bin/env swift

import AppKit
import CoreGraphics

func createIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    
    image.lockFocus()
    
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    
    // Create gradient
    let gradient = NSGradient(colors: [
        NSColor(red: 0.345, green: 0.337, blue: 0.839, alpha: 1.0), // Blue
        NSColor(red: 0.576, green: 0.200, blue: 0.918, alpha: 1.0)  // Purple
    ])
    
    // Draw circular gradient background
    let circlePath = NSBezierPath(ovalIn: rect)
    circlePath.addClip()
    gradient?.draw(in: rect, angle: 135)
    
    // Draw two overlapping circles for "person.2" symbol
    NSColor.white.setFill()
    
    let radius = size * 0.15
    let y = size * 0.5
    
    // Left circle
    let leftCircle = NSBezierPath(ovalIn: NSRect(
        x: size * 0.3 - radius,
        y: y - radius,
        width: radius * 2,
        height: radius * 2
    ))
    leftCircle.fill()
    
    // Right circle
    let rightCircle = NSBezierPath(ovalIn: NSRect(
        x: size * 0.7 - radius,
        y: y - radius,
        width: radius * 2,
        height: radius * 2
    ))
    rightCircle.fill()
    
    image.unlockFocus()
    
    return image
}

func savePNG(image: NSImage, path: String) {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }
    
    try? png.write(to: URL(fileURLWithPath: path))
}

// Create iconset directory
let iconsetPath = "./AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

// Generate all required sizes
let sizes: [(size: CGFloat, name: String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (size, name) in sizes {
    let icon = createIcon(size: size)
    savePNG(image: icon, path: "\(iconsetPath)/\(name)")
    print("Created \(name)")
}

print("\n✓ All icon sizes created successfully!")
print("Now run: iconutil -c icns AppIcon.iconset -o AppIcon.icns")
