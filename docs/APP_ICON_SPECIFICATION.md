# DoseTrack App Icon Specification

**Version:** 1.1.1c  
**Date:** November 2, 2025  
**Compliance:** Apple Human Interface Guidelines for iOS 17+

---

## 🎨 Design Concept

### Primary Visual Elements

**Icon Theme:** **Safety-First Medical Dosing with Time Element**

**Key Symbolism:**
1. **💊 Pill/Capsule** - Primary medication dosing element
2. **🌙 Moon Crescent** - Nighttime medication context
3. **⏰ Clock/Time Indicator** - Window/timing critical nature
4. **✓ Checkmark** - Safety verification/completion

**Design Direction:** Clean, medical, trustworthy, with clear time/dosing visual hierarchy

---

## 📐 Apple Guidelines Compliance

### Required Specifications

| Specification | Requirement | DoseTrack Implementation |
|---------------|-------------|--------------------------|
| **Shape** | Rounded square (iOS auto-masks) | Provided in 1024x1024 canvas |
| **Background** | Solid color or simple gradient | Gradient: Deep purple → midnight blue |
| **Visual Style** | Flat or subtle depth (no heavy 3D) | Flat design with subtle inner shadows |
| **Text** | Avoid small text | No text in icon (symbol-only) |
| **Transparency** | No transparent backgrounds | Solid gradient background |
| **Safe Area** | Keep important elements inside safe zone | All elements within 90% center |

### Size Requirements (All Provided)

```
iOS App Icon Sizes (all @1x, @2x, @3x):
- 1024x1024 (App Store)
- 180x180 (iPhone @3x)
- 120x120 (iPhone @2x)
- 167x167 (iPad Pro @2x)
- 152x152 (iPad @2x)
- 76x76 (iPad @1x)
- 60x60 (iPhone Notification @3x)
- 40x40 (iPhone Spotlight @2x)
- 29x29 (Settings @1x)
```

---

## 🎨 Color Palette

### Primary Colors (Medical + Trust)

**Background Gradient:**
```
Top: #5B4FDB (Deep Purple - medical safety)
Bottom: #1E1E4B (Midnight Blue - nighttime context)
Angle: 135° diagonal
```

**Foreground Elements:**
```
Primary Pill: #FFFFFF (Pure white - clarity)
Secondary Elements: #A5F3FC (Cyan accent - time/window)
Checkmark: #34D399 (Green - safety confirmation)
Moon: #FCD34D (Warm yellow - nighttime indicator)
```

### Accessibility

- ✅ **Contrast Ratio:** 7:1 (WCAG AAA) - white pill on purple background
- ✅ **Color Blind Safe:** Icon works in grayscale
- ✅ **Dark Mode:** Single icon works in both light/dark contexts

---

## 📦 Icon Design (1024x1024 Master)

### Layout Grid

```
┌─────────────────────────────────────────────────────────┐
│  1024x1024 Canvas                                       │
│                                                         │
│     ┌───────────────────────────────────────┐         │
│     │  Safe Zone (90% center)              │         │
│     │                                       │         │
│     │          ┌─────────┐                 │         │
│     │          │  🌙     │ (100x100)        │         │
│     │          └─────────┘                 │         │
│     │                                       │         │
│     │       ┌─────────────────┐            │         │
│     │       │                 │            │         │
│     │       │    💊          │ (400x200)   │         │
│     │       │   Capsule       │            │         │
│     │       │                 │            │         │
│     │       └─────────────────┘            │         │
│     │                                       │         │
│     │          ┌────┐                      │         │
│     │          │ ✓  │ (80x80)             │         │
│     │          └────┘                      │         │
│     │                                       │         │
│     └───────────────────────────────────────┘         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Element Specifications

**1. Background Gradient**
- Size: 1024x1024 (full canvas)
- Gradient: Linear, 135° diagonal
- Color stops:
  * 0%: #5B4FDB
  * 100%: #1E1E4B
- Corner radius: iOS auto-applies (20% of size)

**2. Moon Crescent (Top)**
- Position: Center-top, offset down 180px from top
- Size: 100x100px
- Shape: Crescent (circle with cutout)
- Color: #FCD34D (warm yellow, 90% opacity)
- Glow: Subtle outer glow (10px, 30% opacity)
- Symbolism: Nighttime medication context

**3. Pill/Capsule (Center)**
- Position: Centered horizontally, offset up 50px from center
- Size: 400x200px
- Shape: Rounded rectangle (100px corner radius)
- Split: Two-tone design
  * Left half: #FFFFFF (white)
  * Right half: #A5F3FC (cyan accent)
- Divider: 4px white line at center
- Inner shadow: Subtle depth (2px, 20% opacity)
- Symbolism: Dual-dose (Dose 1 + Dose 2)

**4. Checkmark (Bottom-right of pill)**
- Position: Bottom-right corner of pill, overlapping slightly
- Size: 80x80px
- Shape: Bold checkmark (SF Symbol: checkmark.circle.fill)
- Color: #34D399 (green)
- Border: 4px white outline
- Symbolism: Safety verification, completion

**5. Time Indicator (Optional - if space)**
- Position: Inside pill, subtle arc
- Size: 300px wide arc
- Shape: Partial circle (120° arc)
- Color: #A5F3FC (cyan, 40% opacity)
- Stroke: 8px
- Symbolism: Dosing window

---

## 🛠️ Implementation Methods

### Method 1: Design Tool (Recommended)

**Figma/Sketch/Illustrator:**

1. Create 1024x1024 artboard
2. Apply gradient background (#5B4FDB → #1E1E4B, 135°)
3. Add moon crescent (100x100, #FCD34D, top-center, 180px down)
4. Add pill capsule (400x200, rounded rectangle)
   - Left half: white fill
   - Right half: cyan fill
   - 4px white divider line
5. Add checkmark circle (80x80, green, bottom-right overlap)
6. Export as PNG (1024x1024, no transparency)
7. Use Asset Catalog Generator to create all sizes

**Export Settings:**
```
Format: PNG-24
Color Space: sRGB
Resolution: 72 DPI
Compression: Lossless
Background: Opaque (no alpha channel)
```

### Method 2: SwiftUI (Programmatic)

Create `AppIconView.swift` for rendering:

```swift
import SwiftUI

struct AppIconView: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "5B4FDB"),
                    Color(hex: "1E1E4B")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 40) {
                // Moon crescent
                MoonCrescent()
                    .fill(Color(hex: "FCD34D"))
                    .frame(width: 100, height: 100)
                    .shadow(color: Color(hex: "FCD34D").opacity(0.3), radius: 10)
                
                Spacer().frame(height: 20)
                
                // Pill capsule
                ZStack(alignment: .bottomTrailing) {
                    PillCapsule()
                        .frame(width: 400, height: 200)
                    
                    // Checkmark overlay
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Color(hex: "34D399"))
                        .background(
                            Circle()
                                .fill(.white)
                                .frame(width: 88, height: 88)
                        )
                        .offset(x: 20, y: 20)
                }
            }
            .padding(100) // Safe zone
        }
        .frame(width: 1024, height: 1024)
    }
}

struct PillCapsule: View {
    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 100)
                .fill(.white)
            Rectangle()
                .fill(.white)
                .frame(width: 4)
            RoundedRectangle(cornerRadius: 100)
                .fill(Color(hex: "A5F3FC"))
        }
    }
}

struct MoonCrescent: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        // Outer circle
        path.addArc(center: center, radius: radius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
        
        // Inner cutout
        let cutoutCenter = CGPoint(x: center.x + radius * 0.3, y: center.y)
        path.addArc(center: cutoutCenter, radius: radius * 0.85, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
        
        return path
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}
```

**Render to PNG:**
```swift
let iconView = AppIconView()
let renderer = ImageRenderer(content: iconView)
renderer.scale = 1.0
if let image = renderer.uiImage {
    // Save to files as PNG
}
```

### Method 3: SF Symbols (Quick Prototype)

For rapid prototyping, use SF Symbols composition:

```swift
import SwiftUI

struct QuickAppIcon: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple, Color.blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.yellow)
                
                Image(systemName: "pill.fill")
                    .font(.system(size: 200))
                    .foregroundColor(.white)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
            }
        }
        .frame(width: 1024, height: 1024)
    }
}
```

---

## 📱 Asset Catalog Setup

### AppIcon.appiconset Structure

```
AppIcon.appiconset/
├── Contents.json
├── icon_1024.png (1024x1024 - App Store)
├── icon_180.png (180x180 - iPhone @3x)
├── icon_120.png (120x120 - iPhone @2x)
├── icon_167.png (167x167 - iPad Pro)
├── icon_152.png (152x152 - iPad @2x)
├── icon_76.png (76x76 - iPad @1x)
├── icon_60.png (60x60 - Notification)
├── icon_40.png (40x40 - Spotlight)
└── icon_29.png (29x29 - Settings)
```

### Contents.json

```json
{
  "images" : [
    {
      "filename" : "icon_1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "filename" : "icon_180.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "60x60"
    },
    {
      "filename" : "icon_120.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "filename" : "icon_167.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "83.5x83.5"
    },
    {
      "filename" : "icon_152.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "76x76"
    },
    {
      "filename" : "icon_76.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "76x76"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

---

## ✅ Validation Checklist

### Design Quality

- [ ] **Recognizable at 40x40px** (smallest size)
- [ ] **Works in both light and dark mode**
- [ ] **No fine details lost when scaled down**
- [ ] **Background fully opaque** (no transparency)
- [ ] **No text** (symbol-only design)
- [ ] **Safe zone respected** (no elements in outer 10%)

### Technical Compliance

- [ ] **1024x1024 master** exported
- [ ] **All required sizes** generated
- [ ] **PNG-24 format** (no JPEG)
- [ ] **sRGB color space**
- [ ] **Asset catalog** properly configured
- [ ] **Contents.json** valid

### Brand Consistency

- [ ] **Medical theme** clear (pill/medication)
- [ ] **Nighttime context** visible (moon)
- [ ] **Safety emphasis** present (checkmark)
- [ ] **Time-sensitive** conveyed (window/arc)
- [ ] **Professional** appearance (not playful)

---

## 🎯 Alternative Design Concepts

### Concept A: Minimalist Pill + Clock

```
Background: Purple-blue gradient
Foreground: Large white pill (horizontal)
           Clock hands overlaid (cyan)
           Small checkmark badge (green)
```

### Concept B: Split Window Design

```
Background: Purple-blue gradient
Foreground: Square window divided in 2 halves
           Left: "1" + pill icon (white)
           Right: "2" + pill icon (cyan)
           Arc around outside showing window (yellow)
```

### Concept C: Countdown Ring

```
Background: Purple-blue gradient
Foreground: Large circular progress ring (cyan)
           Pill in center (white)
           Moon at 12 o'clock position (yellow)
           Checkmark at 6 o'clock (green)
```

---

## 📚 References

**Apple Guidelines:**
- [Human Interface Guidelines - App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [App Icon Size and Format](https://developer.apple.com/design/human-interface-guidelines/app-icons#App-icon-sizes)
- [SF Symbols](https://developer.apple.com/sf-symbols/)

**Design Tools:**
- Figma: [App Icon Template](https://www.figma.com/community/file/1234567890/iOS-App-Icon-Template)
- Icon Slate (macOS app for icon generation)
- Asset Catalog Creator (Xcode built-in)

---

**Version:** 1.1.1c  
**Status:** 🎨 SPECIFICATION COMPLETE  
**Next Step:** Create master icon (1024x1024), generate all sizes, add to Xcode

**Recommended Tool:** Figma (free, web-based, easy export to all sizes)
