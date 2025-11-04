//
//  PrimaryButton.swift
//  DoseTrack
//
//  Unified primary button component following design system
//  56pt height, 16pt corner radius, consistent disabled state
//

import SwiftUI

/// Unified primary button component
/// Follows design system: 56pt height, 16pt corner, monospacedDigit support
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var enabled: Bool = true
    var caption: String? = nil
    var longPressAction: (() -> Void)? = nil  // Optional long-press handler
    
    var body: some View {
        VStack(spacing: 4) {
            Button(action: action) {
                HStack(spacing: DT.sm) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.headline)
                    }
                    Text(title)
                        .font(.headline)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .frame(height: DT.primaryButtonHeight)
                .background(
                    RoundedRectangle(cornerRadius: DT.corner)
                        .fill(enabled ? Palette.primary.opacity(0.25) : Palette.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: DT.corner)
                                .strokeBorder(
                                    enabled ? Color.clear : Color.white.opacity(DT.strokeOpacity),
                                    lineWidth: DT.strokeWidth
                                )
                        )
                )
                .foregroundStyle(enabled ? Palette.primary : Palette.dim)
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .simultaneousGesture(
                // Add long-press gesture if handler provided
                longPressAction != nil ? LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        if enabled {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            longPressAction?()
                        }
                    } : nil
            )
            .accessibilityLabel(title)
            .accessibilityHint(enabled ? (longPressAction != nil ? "Tap to \(title.lowercased()), or press and hold to choose time" : "Tap to \(title.lowercased())") : (caption ?? "Currently disabled"))
            .accessibilityAddTraits(enabled ? [] : .isButton)
            
            // Show caption when disabled
            if !enabled, let caption = caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
                    .accessibilityHidden(true) // Already in button hint
            }
        }
    }
}

#Preview {
    VStack(spacing: DT.gap) {
        PrimaryButton(
            title: "Dose 1",
            icon: "pills.fill",
            action: { print("Dose 1") }
        )
        
        PrimaryButton(
            title: "Dose 2",
            icon: "lock.fill",
            action: { print("Dose 2") },
            enabled: false,
            caption: "Log Dose 1 to start the window"
        )
        
        PrimaryButton(
            title: "Final wake",
            icon: "sunrise.fill",
            action: { print("Final wake") }
        )
        
        PrimaryButton(
            title: "No icon",
            icon: nil,
            action: { print("No icon") }
        )
    }
    .padding()
    .background(Palette.bg)
}
