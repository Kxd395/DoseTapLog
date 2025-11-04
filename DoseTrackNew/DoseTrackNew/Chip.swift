//
//  Chip.swift
//  DoseTrack
//
//  Unified chip component - design system compliant
//  Fixed height (36pt), corner radius (14pt), consistent stroke
//  Monospaced digits for numbers
//

import SwiftUI

/// Unified chip component with consistent styling
struct Chip: View {
    let icon: String?
    let text: String
    let tone: ChipTone
    
    init(icon: String? = nil, text: String, tone: ChipTone) {
        self.icon = icon
        self.text = text
        self.tone = tone
    }
    
    var body: some View {
        HStack(spacing: DT.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.callout)
            }
            Text(text)
                .font(.callout.weight(.semibold))
                .monospacedDigit() // Prevents digit jitter
        }
        .frame(height: DT.chipHeight)
        .padding(.horizontal, DT.md)
        .background(
            RoundedRectangle(cornerRadius: DT.chipCorner)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DT.chipCorner)
                .stroke(Color.white.opacity(DT.strokeOpacity), lineWidth: DT.strokeWidth)
        )
        .foregroundStyle(foregroundColor)
    }
    
    private var backgroundColor: Color {
        Palette.chipBackground(tone: tone)
    }
    
    private var foregroundColor: Color {
        switch tone {
        case .ok:      return .green
        case .warn:    return .orange
        case .info:    return .blue
        case .neutral: return Palette.text
        }
    }
}

// MARK: - Previews

#Preview("Chip Variants") {
    VStack(spacing: DT.md) {
        HStack(spacing: DT.md) {
            Chip(icon: "exclamationmark.triangle.fill",
                 text: "Per dose 1.50–4.50 g", tone: .warn)
            Chip(icon: "sum", text: "Planned 8.50 g", tone: .neutral)
        }
        
        HStack(spacing: DT.md) {
            Chip(icon: "checkmark.seal.fill",
                 text: "Health OK", tone: .ok)
            Chip(icon: "bell.slash.fill",
                 text: "Notifications Off", tone: .warn)
        }
        
        HStack(spacing: DT.md) {
            Chip(icon: "book.closed.fill",
                 text: "Logged 4.25 g", tone: .info)
            Chip(icon: "moon.zzz",
                 text: "In bed", tone: .neutral)
        }
    }
    .padding()
    .background(Palette.bg)
}

#Preview("Digit Stability Test") {
    VStack(spacing: DT.md) {
        ForEach([1.11, 8.88, 4.25, 9.99, 0.00], id: \.self) { value in
            Chip(icon: "sum", text: String(format: "%.2f g", value), tone: .neutral)
        }
    }
    .padding()
    .background(Palette.bg)
}
