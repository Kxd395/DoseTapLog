//
//  DesignTokens.swift
//  DoseTrack
//
//  Design system tokens for dark-mode-first UI
//  Per ModernUI.md specification - WHOOP-adjacent aesthetic
//

import SwiftUI

/// Design tokens: spacing, corner radii, shadows
enum DT {
    // Corner radii
    static let corner: CGFloat = 16
    static let chipCorner: CGFloat = 12
    
    // Spacing
    static let pad: CGFloat = 16
    static let gap: CGFloat = 12
    
    // Sizes
    static let minTapTarget: CGFloat = 44
    static let windowBarHeight: CGFloat = 10
}

/// Color palette - dark mode first, muted surfaces, neon accents
struct Palette {
    // MARK: - Surfaces
    static let bg        = Color(red: 0.06, green: 0.07, blue: 0.09)  // #0F1117
    static let surface   = Color(red: 0.12, green: 0.13, blue: 0.16)  // Card background
    static let surfaceHi = Color(red: 0.16, green: 0.18, blue: 0.22)  // Elevated surface
    
    // MARK: - Text
    static let text      = Color.white
    static let dim       = Color.white.opacity(0.65)
    static let tertiary  = Color.white.opacity(0.45)
    
    // MARK: - Accents
    static let primary   = Color(hex: 0x4DA3FF)  // Neon-ish blue
    static let ok        = Color(hex: 0x4CD964)  // Green
    static let warn      = Color(hex: 0xFFB020)  // Amber
    static let danger    = Color(hex: 0xFF453A)  // Red
    
    // MARK: - Semantic colors
    static let dose1     = Color(hex: 0x5E5CE6)  // Purple for dose 1
    static let dose2     = Color(hex: 0x32ADE6)  // Cyan for dose 2
    static let wake      = Color(hex: 0xFF9F0A)  // Orange for wake events
}

extension Color {
    /// Initialize Color from hex value
    /// - Parameters:
    ///   - hex: Hex color value (e.g., 0xFF0000 for red)
    ///   - alpha: Opacity (0.0-1.0)
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255.0
        let g = Double((hex >>  8) & 0xff) / 255.0
        let b = Double((hex >>  0) & 0xff) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
