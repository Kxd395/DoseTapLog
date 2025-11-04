//
//  ModernStatusChipRow.swift
//  DoseTrack
//
//  Horizontal row of status chips that wraps
//

import SwiftUI

struct ChipData {
    let text: String
    let icon: String
    let tone: Color
}

struct ModernStatusChipRow: View {
    let chips: [ChipData]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips.indices, id: \.self) { index in
                    let chip = chips[index]
                    ModernStatusChip(
                        text: chip.text,
                        icon: chip.icon,
                        tone: chip.tone
                    )
                }
            }
        }
    }
}
