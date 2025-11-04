//
//  DesignTokens.swift
//  DoseTrack
//
//  Design system tokens for dark-mode-first UI
//  Per ModernUI.md specification - WHOOP-adjacent aesthetic
//

import SwiftUI

/// Design tokens: spacing, corner radii, shadows
/// Strict 4pt grid system for consistent spacing
enum DT {
    // Corner radii
    static let corner: CGFloat = 16      // Cards, buttons
    static let chipCorner: CGFloat = 14  // Chips
    
    // Spacing (4pt grid)
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    
    // Legacy (kept for compatibility)
    static let pad: CGFloat = 16
    static let gap: CGFloat = 12
    
    // Heights
    static let chipHeight: CGFloat = 36
    static let primaryButtonHeight: CGFloat = 56
    static let windowBarHeight: CGFloat = 10
    
    // Sizes
    static let minTapTarget: CGFloat = 44
    
    // Stroke
    static let strokeWidth: CGFloat = 1
    static let strokeOpacity: Double = 0.08
}

/// Color palette - dark mode first, muted surfaces, neon accents
struct Palette {
    // MARK: - Surfaces
    static let bg        = Color(red: 0.06, green: 0.07, blue: 0.09)  // #0F1117
    static let surface   = Color.white.opacity(0.06)                   // Card background
    static let surfaceHi = Color(red: 0.16, green: 0.18, blue: 0.22)  // Elevated surface
    static let cardBg    = Color.white.opacity(0.06)                   // Alias for surface
    
    // MARK: - Text
    static let text      = Color.white
    static let dim       = Color.white.opacity(0.65)
    static let tertiary  = Color.white.opacity(0.45)
    
    // MARK: - Accents
    static let primary   = Color(hex: 0x4DA3FF)  // Neon-ish blue
    static let accent    = Color.accentColor      // System accent
    static let success   = Color.green            // Green (ok state)
    static let warning   = Color.orange           // Orange (warn state)
    static let danger    = Color.red              // Red (error state)
    
    // Legacy aliases
    static let ok        = Color(hex: 0x4CD964)  // Green
    static let warn      = Color(hex: 0xFFB020)  // Amber
    
    // MARK: - Semantic colors
    static let dose1     = Color(hex: 0x5E5CE6)  // Purple for dose 1
    static let dose2     = Color(hex: 0x32ADE6)  // Cyan for dose 2
    static let wake      = Color(hex: 0xFF9F0A)  // Orange for wake events
    
    // MARK: - Chip backgrounds
    static func chipBackground(tone: ChipTone) -> Color {
        switch tone {
        case .ok:      return Color.green.opacity(0.18)
        case .warn:    return Color.orange.opacity(0.20)
        case .info:    return Color.blue.opacity(0.16)
        case .neutral: return Color.white.opacity(0.06)
        }
    }
}

enum ChipTone {
    case info, ok, warn, neutral
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
