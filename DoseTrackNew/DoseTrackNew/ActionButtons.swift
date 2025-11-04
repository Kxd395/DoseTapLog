//
//  ActionButtons.swift
//  DoseTrack
//
//  Primary and secondary action buttons for dose logging and wake events
//

import SwiftUI

/// Primary action button (for main dose/wake actions)
struct PrimaryActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var disabled: Bool = false
    var caption: String? = nil
    
    var body: some View {
        VStack(spacing: 4) {
            Button(action: action) {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: DT.chipCorner)
                            .fill(disabled ? Palette.surfaceHi : Palette.primary.opacity(0.25))
                    )
                    .foregroundStyle(disabled ? Palette.dim : Palette.primary)
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            
            // Show caption when disabled
            if disabled, let caption = caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
                    .accessibilityHint(caption)
            }
        }
    }
}

/// Secondary action button (for events, reset, etc.)
struct SecondaryActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var tone: Color = Palette.text
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: DT.chipCorner)
                        .fill(Palette.surface)
                )
                .foregroundStyle(tone)
        }
        .buttonStyle(.plain)
    }
}

/// Action grid container (2x2 or 2x3 grid of buttons)
struct ActionGrid: View {
    let primaryActions: [ActionItem]
    let secondaryActions: [ActionItem]
    
    struct ActionItem: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let action: () -> Void
        var disabled: Bool = false
        var tone: Color = Palette.text
        var caption: String? = nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DT.gap) {
            // Primary actions
            Text("Actions")
                .font(.headline)
                .foregroundStyle(Palette.text)
            
            Grid(horizontalSpacing: DT.gap, verticalSpacing: DT.gap) {
                ForEach(0..<(primaryActions.count + 1) / 2, id: \.self) { row in
                    GridRow {
                        if let first = primaryActions[safe: row * 2] {
                            PrimaryActionButton(
                                title: first.title,
                                icon: first.icon,
                                action: first.action,
                                disabled: first.disabled,
                                caption: first.caption
                            )
                        }
                        if let second = primaryActions[safe: row * 2 + 1] {
                            PrimaryActionButton(
                                title: second.title,
                                icon: second.icon,
                                action: second.action,
                                disabled: second.disabled,
                                caption: second.caption
                            )
                        }
                    }
                }
            }
            
            // Secondary actions (events)
            if !secondaryActions.isEmpty {
                Text("Events")
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                    .padding(.top, 4)
                
                Grid(horizontalSpacing: DT.gap, verticalSpacing: DT.gap) {
                    ForEach(0..<(secondaryActions.count + 1) / 2, id: \.self) { row in
                        GridRow {
                            if let first = secondaryActions[safe: row * 2] {
                                SecondaryActionButton(
                                    title: first.title,
                                    icon: first.icon,
                                    action: first.action,
                                    tone: first.tone
                                )
                            }
                            if let second = secondaryActions[safe: row * 2 + 1] {
                                SecondaryActionButton(
                                    title: second.title,
                                    icon: second.icon,
                                    action: second.action,
                                    tone: second.tone
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Previews

#Preview("Primary Buttons") {
    VStack(spacing: 12) {
        PrimaryActionButton(title: "In bed", icon: "moon.fill", action: { })
        PrimaryActionButton(title: "Dose 1", icon: "pills.fill", action: { })
        PrimaryActionButton(
            title: "Dose 2",
            icon: "pills.circle.fill",
            action: { },
            disabled: true,
            caption: "Opens in 1h 17m (210–245 min after Dose 1)"
        )
        PrimaryActionButton(title: "Final wake", icon: "sunrise.fill", action: { })
    }
    .padding()
    .background(Palette.bg)
}

#Preview("Secondary Buttons") {
    VStack(spacing: 12) {
        SecondaryActionButton(title: "Alarm wake", icon: "alarm.fill", action: { })
        SecondaryActionButton(title: "Natural wake", icon: "bed.double.fill", action: { })
        SecondaryActionButton(title: "Bathroom", icon: "figure.walk", action: { })
        SecondaryActionButton(title: "Reset night", icon: "arrow.counterclockwise", action: { }, tone: Palette.danger)
    }
    .padding()
    .background(Palette.bg)
}

#Preview("Action Grid") {
    ActionGrid(
        primaryActions: [
            .init(title: "In bed", icon: "moon.fill", action: {}),
            .init(title: "Dose 1", icon: "pills.fill", action: {}),
            .init(
                title: "Dose 2",
                icon: "pills.circle.fill",
                action: {},
                disabled: true,
                caption: "Opens in 1h 17m (210–245 min after Dose 1)"
            ),
            .init(title: "Final wake", icon: "sunrise.fill", action: {})
        ],
        secondaryActions: [
            .init(title: "Alarm wake", icon: "alarm.fill", action: {}),
            .init(title: "Natural wake", icon: "bed.double.fill", action: {}),
            .init(title: "Bathroom", icon: "figure.walk", action: {}),
            .init(title: "Reset night", icon: "arrow.counterclockwise", action: {}, tone: Palette.danger)
        ]
    )
    .padding()
    .background(Palette.bg)
}
