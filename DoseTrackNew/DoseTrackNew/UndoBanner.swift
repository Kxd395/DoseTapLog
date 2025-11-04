//
//  UndoBanner.swift
//  DoseTrack
//
//  Countdown banner for undo window after dose logging
//

import SwiftUI

struct UndoBanner: View {
    let actionName: String
    let secondsRemaining: Int
    let onUndo: () -> Void
    
    var body: some View {
        HStack(spacing: DT.md) {
            // Icon
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            
            // Message
            VStack(alignment: .leading, spacing: 2) {
                Text("Logged \(actionName)")
                    .font(.callout.weight(.semibold))
                Text("Undo available for \(secondsRemaining)s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Undo button
            Button(action: onUndo) {
                Text("Undo")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DT.md)
                    .padding(.vertical, DT.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.orange)
                    )
            }
        }
        .padding(DT.md)
        .background(
            RoundedRectangle(cornerRadius: DT.corner)
                .fill(Palette.surface)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
        )
        .padding(.horizontal, DT.gap)
    }
}

#Preview {
    VStack(spacing: 20) {
        UndoBanner(
            actionName: "Dose 1 (4.25 g)",
            secondsRemaining: 28,
            onUndo: { }
        )
        
        UndoBanner(
            actionName: "Dose 2 (4.50 g)",
            secondsRemaining: 15,
            onUndo: { }
        )
        
        UndoBanner(
            actionName: "Final wake",
            secondsRemaining: 5,
            onUndo: { }
        )
    }
    .padding()
    .background(Palette.bg)
}
