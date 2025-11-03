#!/usr/bin/swift
//
// DoseTrack App Icon Generator
// Generates a 1024x1024 PNG app icon based on the APP_ICON_SPECIFICATION.md design
//
// Usage: swift scripts/generate-app-icon.swift
//

import Foundation
import AppKit
import CoreGraphics

// MARK: - Color Extensions

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1.0
        )
    }
}

// MARK: - Icon Generator

class AppIconGenerator {
    let size: CGFloat = 1024
    
    func generate() -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        
        // Draw background gradient
        drawGradientBackground(in: context)
        
        // Draw moon crescent (top)
        drawMoonCrescent(in: context)
        
        // Draw pill capsule (center)
        drawPillCapsule(in: context)
        
        // Draw checkmark (bottom-right of pill)
        drawCheckmark(in: context)
        
        image.unlockFocus()
        return image
    }
    
    private func drawGradientBackground(in context: CGContext) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            NSColor(hex: "5B4FDB").cgColor,
            NSColor(hex: "1E1E4B").cgColor
        ] as CFArray
        
        let locations: [CGFloat] = [0.0, 1.0]
        
        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors,
            locations: locations
        ) else { return }
        
        // 135° diagonal gradient
        let startPoint = CGPoint(x: 0, y: size)
        let endPoint = CGPoint(x: size, y: 0)
        
        context.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: []
        )
    }
    
    private func drawMoonCrescent(in context: CGContext) {
        let moonSize: CGFloat = 100
        let moonX = size / 2
        let moonY = size - 180 - moonSize / 2
        
        context.saveGState()
        
        // Outer circle (full moon)
        let outerCircle = CGRect(
            x: moonX - moonSize / 2,
            y: moonY - moonSize / 2,
            width: moonSize,
            height: moonSize
        )
        
        // Inner circle (cutout to create crescent)
        let cutoutOffset: CGFloat = 20
        let innerCircle = CGRect(
            x: moonX - moonSize / 2 + cutoutOffset,
            y: moonY - moonSize / 2,
            width: moonSize,
            height: moonSize
        )
        
        // Create crescent shape using even-odd fill rule
        let path = CGMutablePath()
        path.addEllipse(in: outerCircle)
        path.addEllipse(in: innerCircle)
        
        context.setFillColor(NSColor(hex: "FCD34D").withAlphaComponent(0.9).cgColor)
        context.addPath(path)
        context.fillPath(using: .evenOdd)
        
        // Add subtle glow
        context.saveGState()
        context.setShadow(
            offset: .zero,
            blur: 10,
            color: NSColor(hex: "FCD34D").withAlphaComponent(0.3).cgColor
        )
        context.addPath(path)
        context.fillPath(using: .evenOdd)
        context.restoreGState()
        
        context.restoreGState()
    }
    
    private func drawPillCapsule(in context: CGContext) {
        let pillWidth: CGFloat = 400
        let pillHeight: CGFloat = 200
        let pillX = size / 2 - pillWidth / 2
        let pillY = size / 2 - pillHeight / 2 + 50
        let cornerRadius: CGFloat = 100
        
        // Full pill shape
        let pillRect = CGRect(x: pillX, y: pillY, width: pillWidth, height: pillHeight)
        let pillPath = CGPath(
            roundedRect: pillRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        
        context.saveGState()
        
        // Add subtle shadow for depth
        context.setShadow(
            offset: CGSize(width: 0, height: 4),
            blur: 8,
            color: NSColor.black.withAlphaComponent(0.2).cgColor
        )
        
        // Left half (white)
        context.saveGState()
        let leftClip = CGRect(x: pillX, y: pillY, width: pillWidth / 2, height: pillHeight)
        context.addPath(pillPath)
        context.clip()
        context.addRect(leftClip)
        context.setFillColor(NSColor.white.cgColor)
        context.fillPath()
        context.restoreGState()
        
        // Right half (cyan)
        context.saveGState()
        let rightClip = CGRect(x: pillX + pillWidth / 2, y: pillY, width: pillWidth / 2, height: pillHeight)
        context.addPath(pillPath)
        context.clip()
        context.addRect(rightClip)
        context.setFillColor(NSColor(hex: "A5F3FC").cgColor)
        context.fillPath()
        context.restoreGState()
        
        context.restoreGState()
        
        // Center divider line
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(4)
        context.move(to: CGPoint(x: size / 2, y: pillY))
        context.addLine(to: CGPoint(x: size / 2, y: pillY + pillHeight))
        context.strokePath()
        
        // Subtle inner shadow for pill depth
        context.saveGState()
        context.addPath(pillPath)
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.1).cgColor)
        context.setLineWidth(2)
        context.strokePath()
        context.restoreGState()
    }
    
    private func drawCheckmark(in context: CGContext) {
        let checkSize: CGFloat = 80
        let pillWidth: CGFloat = 400
        let pillHeight: CGFloat = 200
        let pillX = size / 2 - pillWidth / 2
        let pillY = size / 2 - pillHeight / 2 + 50
        
        // Position at bottom-right of pill
        let checkX = pillX + pillWidth - checkSize / 2
        let checkY = pillY - checkSize / 2 + 20
        
        // Outer circle (white border)
        let outerCircle = CGRect(
            x: checkX - checkSize / 2 - 2,
            y: checkY - checkSize / 2 - 2,
            width: checkSize + 4,
            height: checkSize + 4
        )
        context.setFillColor(NSColor.white.cgColor)
        context.fillEllipse(in: outerCircle)
        
        // Inner circle (green)
        let innerCircle = CGRect(
            x: checkX - checkSize / 2,
            y: checkY - checkSize / 2,
            width: checkSize,
            height: checkSize
        )
        context.setFillColor(NSColor(hex: "34D399").cgColor)
        context.fillEllipse(in: innerCircle)
        
        // Checkmark symbol
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(8)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        // Draw checkmark path
        let checkPath = CGMutablePath()
        checkPath.move(to: CGPoint(x: checkX - 18, y: checkY))
        checkPath.addLine(to: CGPoint(x: checkX - 5, y: checkY - 13))
        checkPath.addLine(to: CGPoint(x: checkX + 18, y: checkY + 18))
        
        context.addPath(checkPath)
        context.strokePath()
    }
    
    func saveToPNG(image: NSImage, path: String) -> Bool {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("❌ Failed to get CGImage")
            return false
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        bitmapRep.size = image.size
        
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("❌ Failed to generate PNG data")
            return false
        }
        
        let url = URL(fileURLWithPath: path)
        
        do {
            try pngData.write(to: url)
            print("✅ App icon saved to: \(path)")
            return true
        } catch {
            print("❌ Failed to write PNG file: \(error)")
            return false
        }
    }
}

// MARK: - Main Execution

let generator = AppIconGenerator()
let icon = generator.generate()

// Determine output path
let currentDir = FileManager.default.currentDirectoryPath
let outputPath = "\(currentDir)/DoseTrackNew/DoseTrackNew/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

if generator.saveToPNG(image: icon, path: outputPath) {
    print("✅ DoseTrack app icon generated successfully!")
    print("📦 Location: \(outputPath)")
    print("📱 Open DoseTrackNew.xcodeproj in Xcode to see the icon")
} else {
    print("❌ Failed to generate app icon")
    exit(1)
}
