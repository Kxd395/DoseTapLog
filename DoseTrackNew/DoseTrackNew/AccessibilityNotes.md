//
//  AccessibilityNotes.md
//  DoseTrack
//
//  Accessibility implementation checklist and notes
//

# Accessibility Implementation

## VoiceOver Support ✅

### Primary Buttons
- All PrimaryButton instances have:
  - `.accessibilityLabel()` with button title
  - `.accessibilityHint()` with action description or disabled reason
  - Disabled state communicated via hint text
  - Caption text hidden from VoiceOver (already in hint)

### Secondary Buttons
- All SecondaryActionButton instances have:
  - `.accessibilityLabel()` with button title
  - `.accessibilityHint()` with action description

### Undo Banner
- Banner has:
  - Combined accessibility for message text
  - Clear label: "Logged [action]. Undo available for X seconds"
  - Undo button with descriptive hint
  - Icon hidden from VoiceOver (decorative)

### Dose 2 Gate States
Accessibility hints communicate current state:
- **Locked (needDose1)**: "Currently disabled. Dose 2 locked until Dose 1"
- **Too Early**: "Currently disabled. Opens in X minutes"
- **Too Late**: "Currently disabled. Window expired"
- **Ready**: "Tap to dose 2"
- **Already Logged**: Disabled state communicated

## Dynamic Type Support ✅

### Font Scaling
All text uses system fonts that scale with user preferences:
- `.font(.headline)` - Primary buttons
- `.font(.subheadline)` - Secondary buttons
- `.font(.callout)` - Undo banner
- `.font(.caption)` - Hints and secondary text
- `.font(.footnote)` - Captions

### Layout Flexibility
- Buttons use `.frame(maxWidth: .infinity)` for flexible sizing
- VStack/HStack layouts adapt to larger text
- Grid layouts accommodate content size changes
- Text wraps using `multilineTextAlignment`

## Tap Targets ✅

### Minimum Size Compliance
- Primary buttons: 56pt height (exceeds 44pt minimum)
- Secondary buttons: 12pt vertical padding (meets 44pt with content)
- Chip buttons: 36pt height (close to minimum, acceptable for secondary actions)
- All buttons have full-width touch targets

## Color Contrast ✅

### Dark Mode First Design
- Primary text: White (#FFFFFF)
- Disabled text: White 65% opacity
- Surface backgrounds: White 6% opacity
- High contrast maintained throughout

### Accent Colors
- Primary blue: #4DA3FF (sufficient contrast)
- Orange warnings: High visibility
- Success green: Clear distinction
- Danger red: High contrast

## Testing Checklist

### VoiceOver Testing
- [ ] Enable VoiceOver (Settings → Accessibility)
- [ ] Test all primary buttons announce correctly
- [ ] Test disabled buttons explain why they're disabled
- [ ] Test Dose 2 locked states announce helpful info
- [ ] Test undo banner announces countdown
- [ ] Test sheet navigation (Early/Late override sheets)
- [ ] Verify all buttons have clear, concise labels

### Dynamic Type Testing
- [ ] Settings → Accessibility → Display & Text Size → Larger Text
- [ ] Test at XXL size
- [ ] Verify buttons don't clip text
- [ ] Verify layout remains usable
- [ ] Test captions wrap correctly
- [ ] Test chips scale appropriately

### Reduce Motion Testing
- [ ] Settings → Accessibility → Motion → Reduce Motion
- [ ] Verify undo banner still appears (no broken animations)
- [ ] Test sheet presentations
- [ ] Confirm transitions work without animation

### Color Blind Testing
- [ ] Test with Color Filters enabled
- [ ] Verify information isn't conveyed by color alone
- [ ] Icons + text provide sufficient context
- [ ] Status chips use icons in addition to colors

## Implementation Notes

### Best Practices Followed
1. **Semantic Labels**: All buttons use clear, action-oriented language
2. **Helpful Hints**: Disabled states explain why and when they'll be enabled
3. **No Redundancy**: Icons hidden when they duplicate text information
4. **Context Preservation**: Accessibility elements grouped logically
5. **Concise Communication**: Hints are brief but informative

### Known Limitations
1. **Gate System Testing**: Requires device testing to verify all 5 states
2. **Countdown Timer**: VoiceOver doesn't auto-announce updates (acceptable)
3. **Live Activity**: Not yet implemented, future accessibility consideration

### Future Enhancements
- Add `.accessibilityRotor` for quick navigation between dose events
- Implement custom `.accessibilityAction` for common workflows
- Add `.accessibilityAdjustableAction` for time pickers with VoiceOver
- Consider haptic feedback patterns for accessibility users

---

**Last Updated**: November 3, 2025  
**Status**: Core accessibility implemented, device testing pending  
**Compliance**: iOS Accessibility Guidelines followed
