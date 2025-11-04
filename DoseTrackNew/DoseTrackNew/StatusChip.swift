//
//  StatusChip.swift
//  DoseTrack
//
//  Compact status indicator chips for health, notifications, wake source, etc.
//  Note: Renamed to ModernStatusChip to avoid conflict with SafetyBannerView's StatusChip
//

import SwiftUI

/// Compact status chip with icon, text, and color tone (Modern UI design)
struct ModernStatusChip: View {
    let text: String
    let icon: String?
    let tone: Color
    let action: (() -> Void)?
    
    init(text: String, icon: String? = nil, tone: Color = Palette.dim, action: (() -> Void)? = nil) {
        self.text = text
        self.icon = icon
        self.tone = tone
        self.action = action
    }
    
    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    chipContent
                }
                .buttonStyle(.plain)
            } else {
                chipContent
            }
        }
    }
    
    @ViewBuilder
    private var chipContent: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.callout)
            }
            Text(text)
                .font(.callout)
                .bold()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            Capsule()
                .fill(tone.opacity(0.18))
        )
        .foregroundStyle(tone)
    }
}

/// Scrollable row of status chips
struct ModernStatusChipRow: View {
    let chips: [ChipData]
    
    struct ChipData: Identifiable {
        let id = UUID()
        let text: String
        let icon: String?
        let tone: Color
        let action: (() -> Void)?
        
        init(text: String, icon: String? = nil, tone: Color = Palette.dim, action: (() -> Void)? = nil) {
            self.text = text
            self.icon = icon
            self.tone = tone
            self.action = action
        }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(chips) { chip in
                    ModernStatusChip(
                        text: chip.text,
                        icon: chip.icon,
                        tone: chip.tone,
                        action: chip.action
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Previews

#Preview("Single Chips") {
    VStack(spacing: 12) {
        ModernStatusChip(text: "Health OK", icon: "heart.fill", tone: Palette.ok)
        ModernStatusChip(text: "WHOOP Offline", icon: "antenna.radiowaves.left.and.right", tone: Palette.warn)
        ModernStatusChip(text: "Notifications Disabled", icon: "bell.slash.fill", tone: Palette.danger)
        ModernStatusChip(text: "Wake: Manual", icon: "bed.double.fill", tone: Palette.dim)
        ModernStatusChip(text: "Fix", icon: "wrench.fill", tone: Palette.primary) { }
    }
    .padding()
    .background(Palette.bg)
}

#Preview("Chip Row") {
    ModernStatusChipRow(chips: [
        .init(text: "Per dose 2.5-4.0g", icon: "checkmark.seal.fill", tone: Palette.ok),
        .init(text: "Night total 6.5g", icon: "sum", tone: Palette.dim),
        .init(text: "Health OK", icon: "heart.fill", tone: Palette.ok),
        .init(text: "WHOOP Offline", icon: "antenna.radiowaves.left.and.right", tone: Palette.warn),
        .init(text: "Wake: Manual", icon: "bed.double.fill", tone: Palette.dim)
    ])
    .padding(.vertical)
    .background(Palette.bg)
}
