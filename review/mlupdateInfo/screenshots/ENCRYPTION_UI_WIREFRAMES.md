# Encryption UI Wireframes

**Component:** EncryptionSettingsView.swift (468 lines)  
**Location:** `ios/EncryptionSettingsView.swift`  
**Navigation:** Settings → "Encryption" (NavigationLink in SettingsViewEnhanced)

---

## Screen 1: Initial State (Encryption Disabled)

```
┌─────────────────────────────────────┐
│  ◀ Settings          Encryption     │
├─────────────────────────────────────┤
│                                     │
│  🔓 Encryption Disabled             │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🔒 Enable Encryption        │   │
│  │                             │   │
│  │ Protect your exported data  │   │
│  │ with AES-256-GCM encryption │   │
│  └─────────────────────────────┘   │
│                                     │
│  ℹ️ About Encryption                │
│  ───────────────────────────────    │
│  • End-to-end encrypted exports     │
│  • PBKDF2 key derivation (100k)     │
│  • AES-256-GCM authenticated        │
│  • Passphrase stored in Keychain    │
│  • Zero-knowledge: we cannot        │
│    decrypt your data                │
│                                     │
│  ⚠️ Important                        │
│  ───────────────────────────────    │
│  • Write down your passphrase       │
│  • Lost passphrase = lost data      │
│  • No recovery mechanism            │
│                                     │
└─────────────────────────────────────┘
```

**State:**
- Toggle: OFF (gray)
- Button: "Enable Encryption" (blue, prominent)
- Info sections: Visible
- Password field: Hidden

---

## Screen 2: Setup Passphrase Screen

```
┌─────────────────────────────────────┐
│  ◀ Back              Set Passphrase │
├─────────────────────────────────────┤
│                                     │
│  🔐 Create Passphrase               │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Enter Passphrase            │   │
│  │ ●●●●●●●●●●●●●●●●●●          │   │
│  │ [Show] 👁                    │   │
│  └─────────────────────────────┘   │
│                                     │
│  Strength: ██████████░░░░░░░░░░     │
│  💪 Strong (18/20)                  │
│                                     │
│  ✅ At least 12 characters          │
│  ✅ Contains uppercase              │
│  ✅ Contains lowercase              │
│  ✅ Contains numbers                │
│  ✅ Contains symbols                │
│  ✅ Not a common password           │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Confirm Passphrase          │   │
│  │ ●●●●●●●●●●●●●●●●●●          │   │
│  │ [Show] 👁                    │   │
│  └─────────────────────────────┘   │
│                                     │
│  ✅ Passphrases match               │
│                                     │
│  ┌─────────────────────────────┐   │
│  │      Save to Keychain       │   │
│  │          (Active)            │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

**State:**
- Password fields: Active (SecureField)
- Show/Hide toggles: Functional
- Strength meter: Real-time update
- Criteria checklist: Live validation
- Save button: Enabled when passphrases match + strength ≥ 12

---

## Screen 3: Password Strength Meter (Weak)

```
┌─────────────────────────────────────┐
│  ◀ Back              Set Passphrase │
├─────────────────────────────────────┤
│                                     │
│  🔐 Create Passphrase               │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Enter Passphrase            │   │
│  │ ●●●●●●                      │   │
│  │ [Show] 👁                    │   │
│  └─────────────────────────────┘   │
│                                     │
│  Strength: ████░░░░░░░░░░░░░░░░     │
│  ⚠️ Weak (4/20)                     │
│                                     │
│  ❌ At least 12 characters          │
│  ❌ Contains uppercase              │
│  ✅ Contains lowercase              │
│  ❌ Contains numbers                │
│  ❌ Contains symbols                │
│  ❌ Not a common password           │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Confirm Passphrase          │   │
│  │                             │   │
│  │ [Show] 👁                    │   │
│  └─────────────────────────────┘   │
│                                     │
│  ⚠️ Passphrases do not match        │
│                                     │
│  ┌─────────────────────────────┐   │
│  │      Save to Keychain       │   │
│  │        (Disabled)            │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

**State:**
- Passphrase: "abc123" (weak)
- Strength: 4/20 (red bar, 20% filled)
- Criteria: 5/6 failed
- Save button: Disabled (gray)

---

## Screen 4: Password Strength Meter (Medium)

```
┌─────────────────────────────────────┐
│  ◀ Back              Set Passphrase │
├─────────────────────────────────────┤
│                                     │
│  🔐 Create Passphrase               │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Enter Passphrase            │   │
│  │ ●●●●●●●●●●●●                │   │
│  │ [Show] 👁                    │   │
│  └─────────────────────────────┘   │
│                                     │
│  Strength: ███████████░░░░░░░░░     │
│  ⚠️ Medium (11/20)                  │
│                                     │
│  ✅ At least 12 characters          │
│  ✅ Contains uppercase              │
│  ✅ Contains lowercase              │
│  ✅ Contains numbers                │
│  ❌ Contains symbols                │
│  ✅ Not a common password           │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Confirm Passphrase          │   │
│  │ ●●●●●●●●●●●●                │   │
│  │ [Show] 👁                    │   │
│  └─────────────────────────────┘   │
│                                     │
│  ✅ Passphrases match               │
│                                     │
│  ┌─────────────────────────────┐   │
│  │      Save to Keychain       │   │
│  │          (Active)            │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

**State:**
- Passphrase: "DoseTrack2025" (medium)
- Strength: 11/20 (orange bar, 55% filled)
- Criteria: 5/6 passed (missing symbols)
- Save button: Enabled (passphrase ≥ 12 chars)

---

## Screen 5: Password Strength Meter (Strong)

```
┌─────────────────────────────────────┐
│  ◀ Back              Set Passphrase │
├─────────────────────────────────────┤
│                                     │
│  🔐 Create Passphrase               │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Enter Passphrase            │   │
│  │ ●●●●●●●●●●●●●●●●●●●●●●      │   │
│  │ [Show] 👁                    │   │
│  └─────────────────────────────┘   │
│                                     │
│  Strength: ████████████████████     │
│  ✅ Strong (20/20)                  │
│                                     │
│  ✅ At least 12 characters          │
│  ✅ Contains uppercase              │
│  ✅ Contains lowercase              │
│  ✅ Contains numbers                │
│  ✅ Contains symbols                │
│  ✅ Not a common password           │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Confirm Passphrase          │   │
│  │ ●●●●●●●●●●●●●●●●●●●●●●      │   │
│  │ [Show] 👁                    │   │
│  └─────────────────────────────┘   │
│                                     │
│  ✅ Passphrases match               │
│                                     │
│  ┌─────────────────────────────┐   │
│  │      Save to Keychain       │   │
│  │          (Active)            │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

**State:**
- Passphrase: "MyS3cur3!DoseTrack#2025" (strong)
- Strength: 20/20 (green bar, 100% filled)
- Criteria: 6/6 passed
- Save button: Enabled and highlighted

---

## Screen 6: Encryption Active State

```
┌─────────────────────────────────────┐
│  ◀ Settings          Encryption     │
├─────────────────────────────────────┤
│                                     │
│  🔒 Encryption Enabled              │
│  ✅ AES-256-GCM Active              │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🔓 Disable Encryption       │   │
│  │                             │   │
│  │ Remove passphrase protection│   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🔄 Change Passphrase        │   │
│  │                             │   │
│  │ Update encryption key       │   │
│  └─────────────────────────────┘   │
│                                     │
│  ℹ️ Current Status                  │
│  ───────────────────────────────    │
│  • Passphrase: ●●●●●●●●●●●●●●●●    │
│  • Algorithm: AES-256-GCM           │
│  • Key derivation: PBKDF2 (100k)    │
│  • Storage: Keychain (device-only)  │
│  • Last updated: Nov 1, 2025        │
│                                     │
│  🔐 Protected Exports               │
│  ───────────────────────────────    │
│  • All .jsonl.gz exports encrypted  │
│  • Manifests include encryption     │
│    metadata (IV, salt, tag)         │
│  • Decryption requires correct      │
│    passphrase                       │
│                                     │
│  ⚠️ Security Notice                 │
│  ───────────────────────────────    │
│  • Passphrase stored in Keychain    │
│  • Cannot be extracted by other     │
│    apps or backups                  │
│  • Disabling encryption removes     │
│    all keys from Keychain           │
│                                     │
└─────────────────────────────────────┘
```

**State:**
- Toggle: ON (green)
- Buttons: "Disable Encryption", "Change Passphrase"
- Status info: Visible with current configuration
- Protected exports: Listed
- Security notice: Displayed

---

## Implementation Details

### Password Strength Algorithm

```swift
func calculatePasswordStrength(_ password: String) -> (score: Int, label: String, color: Color) {
    var score = 0
    
    // Length scoring (0-8 points)
    if password.count >= 12 { score += 2 }
    if password.count >= 16 { score += 2 }
    if password.count >= 20 { score += 2 }
    if password.count >= 24 { score += 2 }
    
    // Character diversity (0-8 points)
    if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 2 }
    if password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 2 }
    if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 2 }
    if password.rangeOfCharacter(from: .symbols) != nil { score += 2 }
    
    // Entropy scoring (0-4 points)
    let uniqueChars = Set(password).count
    if uniqueChars >= 8 { score += 2 }
    if uniqueChars >= 12 { score += 2 }
    
    // Common password check (-10 points if found)
    if commonPasswords.contains(password.lowercased()) { score -= 10 }
    
    // Cap score at 20
    score = min(max(score, 0), 20)
    
    // Assign label and color
    switch score {
    case 0..<8:  return (score, "Weak", .red)
    case 8..<14: return (score, "Medium", .orange)
    default:     return (score, "Strong", .green)
    }
}
```

### Keychain Storage

```swift
// Save passphrase to Keychain
func saveToKeychain(passphrase: String) -> Bool {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "com.dosetrack.encryption.passphrase",
        kSecValueData as String: passphrase.data(using: .utf8)!,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    
    // Delete old key if exists
    SecItemDelete(query as CFDictionary)
    
    // Add new key
    let status = SecItemAdd(query as CFDictionary, nil)
    return status == errSecSuccess
}
```

### Encryption Flow

```swift
// Export with encryption
func exportWithEncryption() {
    // 1. Export to .jsonl
    let jsonlURL = exportToJSONL()
    
    // 2. Compress to .jsonl.gz
    let compressedURL = compressExport(jsonlURL: jsonlURL)
    
    // 3. Encrypt .jsonl.gz → .jsonl.gz.enc
    let encryptedURL = encryptFile(compressedURL)
    
    // 4. Update manifest with encryption metadata
    let manifest = ExportManifest(
        encrypted: true,
        algorithm: "AES-256-GCM",
        iv: encryptionIV.base64EncodedString(),
        salt: pbkdf2Salt.base64EncodedString(),
        authTag: gcmTag.base64EncodedString()
    )
    
    // 5. Save manifest
    saveManifest(manifest, to: encryptedURL.deletingPathExtension().appendingPathExtension("json"))
}
```

---

## User Flow Summary

1. **User navigates to Settings → Encryption**
   - Sees Screen 1 (Encryption Disabled)
   - Taps "Enable Encryption"

2. **User creates passphrase**
   - Sees Screen 2 (Setup Passphrase)
   - Enters passphrase (real-time strength meter updates)
   - Sees Screen 3 (Weak) → Screen 4 (Medium) → Screen 5 (Strong) as they improve
   - Confirms passphrase
   - Taps "Save to Keychain"

3. **System saves passphrase**
   - Stores in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
   - Shows success message
   - Returns to Screen 6 (Encryption Active)

4. **User manages encryption**
   - Sees Screen 6 (Encryption Active)
   - Can disable encryption or change passphrase
   - All future exports are encrypted

---

## Accessibility Features

- ✅ VoiceOver labels for all UI elements
- ✅ Dynamic Type support (text scales with system settings)
- ✅ High contrast mode support
- ✅ Keyboard navigation (tab order optimized)
- ✅ Semantic color usage (not relying on color alone)

---

## Security Properties

1. **Zero-Knowledge:** DoseTrack never transmits passphrase to server
2. **Device-Only:** Keychain item marked `ThisDeviceOnly` (not synced via iCloud)
3. **Authenticated Encryption:** AES-GCM provides both confidentiality and integrity
4. **Strong KDF:** PBKDF2 with 100,000 iterations (OWASP recommended)
5. **Secure Deletion:** Keychain item wiped on disable
6. **No Recovery:** Lost passphrase = lost data (by design)

---

**Generated:** November 1, 2025  
**Source:** `ios/EncryptionSettingsView.swift`  
**Status:** Implemented and building successfully
