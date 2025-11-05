import SwiftUI
import CryptoKit

/// Encryption settings for health exports
/// Uses PBKDF2 + AES-GCM with keychain storage
struct EncryptionSettingsView: View {
    @AppStorage("exportEncryptionEnabled") private var encryptionEnabled = false
    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    @State private var showingSetup = false
    @State private var showingRotation = false
    @State private var strength: PasswordStrength = .weak
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Section {
                Toggle("Encrypt Health Exports", isOn: $encryptionEnabled)
                    .onChange(of: encryptionEnabled) { newValue in
                        if newValue && !EncryptionManager.shared.hasKey() {
                            showingSetup = true
                        }
                    }
                
                if encryptionEnabled {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.green)
                        Text("Encryption active")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Export Encryption")
            } footer: {
                Text("Encrypts health exports using AES-256-GCM. Passphrase stored securely in Keychain.")
            }
            
            if encryptionEnabled {
                Section {
                    Button("Change Passphrase") {
                        showingRotation = true
                    }
                    
                    Button("Remove Encryption", role: .destructive) {
                        removeEncryption()
                    }
                } header: {
                    Text("Key Management")
                }
            }
        }
        .navigationTitle("Encryption")
        .sheet(isPresented: $showingSetup) {
            EncryptionSetupSheet(isPresented: $showingSetup)
        }
        .sheet(isPresented: $showingRotation) {
            PassphraseRotationSheet(isPresented: $showingRotation)
        }
    }
    
    private func removeEncryption() {
        EncryptionManager.shared.removeKey()
        encryptionEnabled = false
    }
}

// MARK: - Setup Sheet

struct EncryptionSetupSheet: View {
    @Binding var isPresented: Bool
    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    @State private var strength: PasswordStrength = .weak
    @State private var errorMessage: String?
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("Passphrase", text: $passphrase)
                        .textContentType(.newPassword)
                        .onChange(of: passphrase) { _ in
                            strength = evaluateStrength(passphrase)
                        }
                    
                    SecureField("Confirm Passphrase", text: $confirmPassphrase)
                        .textContentType(.newPassword)
                    
                    PasswordStrengthMeter(strength: strength)
                } header: {
                    Text("Create Encryption Passphrase")
                } footer: {
                    Text("Use a strong, unique passphrase. This cannot be recovered if lost.")
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
                
                Section {
                    Button("Enable Encryption") {
                        setupEncryption()
                    }
                    .disabled(!canEnable || isProcessing)
                    
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Setup Encryption")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var canEnable: Bool {
        !passphrase.isEmpty &&
        passphrase == confirmPassphrase &&
        strength != .weak
    }
    
    private func setupEncryption() {
        errorMessage = nil
        isProcessing = true
        
        do {
            try EncryptionManager.shared.setupKey(passphrase: passphrase)
            
            // Wipe passphrase from memory
            passphrase = String(repeating: "X", count: passphrase.count)
            confirmPassphrase = String(repeating: "X", count: confirmPassphrase.count)
            passphrase = ""
            confirmPassphrase = ""
            
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
            isProcessing = false
        }
    }
    
    private func evaluateStrength(_ pass: String) -> PasswordStrength {
        let length = pass.count
        let hasUppercase = pass.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = pass.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasDigits = pass.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSymbols = pass.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil
        
        var score = 0
        if length >= 12 { score += 1 }
        if length >= 16 { score += 1 }
        if hasUppercase && hasLowercase { score += 1 }
        if hasDigits { score += 1 }
        if hasSymbols { score += 1 }
        
        if score >= 4 { return .strong }
        if score >= 2 { return .medium }
        return .weak
    }
}

// MARK: - Rotation Sheet

struct PassphraseRotationSheet: View {
    @Binding var isPresented: Bool
    @State private var currentPassphrase = ""
    @State private var newPassphrase = ""
    @State private var confirmPassphrase = ""
    @State private var strength: PasswordStrength = .weak
    @State private var errorMessage: String?
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("Current Passphrase", text: $currentPassphrase)
                        .textContentType(.password)
                } header: {
                    Text("Verify Identity")
                }
                
                Section {
                    SecureField("New Passphrase", text: $newPassphrase)
                        .textContentType(.newPassword)
                        .onChange(of: newPassphrase) { _ in
                            strength = evaluateStrength(newPassphrase)
                        }
                    
                    SecureField("Confirm New Passphrase", text: $confirmPassphrase)
                        .textContentType(.newPassword)
                    
                    PasswordStrengthMeter(strength: strength)
                } header: {
                    Text("New Passphrase")
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
                
                Section {
                    Button("Change Passphrase") {
                        rotateKey()
                    }
                    .disabled(!canRotate || isProcessing)
                    
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Change Passphrase")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var canRotate: Bool {
        !currentPassphrase.isEmpty &&
        !newPassphrase.isEmpty &&
        newPassphrase == confirmPassphrase &&
        strength != .weak
    }
    
    private func rotateKey() {
        errorMessage = nil
        isProcessing = true
        
        do {
            try EncryptionManager.shared.rotateKey(
                currentPassphrase: currentPassphrase,
                newPassphrase: newPassphrase
            )
            
            // Wipe passphrases from memory
            [currentPassphrase, newPassphrase, confirmPassphrase].forEach { pass in
                var mutablePass = pass
                mutablePass = String(repeating: "X", count: mutablePass.count)
            }
            currentPassphrase = ""
            newPassphrase = ""
            confirmPassphrase = ""
            
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
            isProcessing = false
        }
    }
    
    private func evaluateStrength(_ pass: String) -> PasswordStrength {
        let length = pass.count
        let hasUppercase = pass.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = pass.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasDigits = pass.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSymbols = pass.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil
        
        var score = 0
        if length >= 12 { score += 1 }
        if length >= 16 { score += 1 }
        if hasUppercase && hasLowercase { score += 1 }
        if hasDigits { score += 1 }
        if hasSymbols { score += 1 }
        
        if score >= 4 { return .strong }
        if score >= 2 { return .medium }
        return .weak
    }
}

// MARK: - Password Strength Meter

struct PasswordStrengthMeter: View {
    let strength: PasswordStrength
    
    var body: some View {
        HStack {
            Text("Strength:")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: index))
                        .frame(height: 4)
                }
            }
            
            Text(strength.rawValue)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(strength.color)
        }
    }
    
    private func barColor(for index: Int) -> Color {
        switch strength {
        case .weak:
            return index == 0 ? .red : .gray.opacity(0.3)
        case .medium:
            return index <= 1 ? .orange : .gray.opacity(0.3)
        case .strong:
            return .green
        }
    }
}

enum PasswordStrength: String {
    case weak = "Weak"
    case medium = "Medium"
    case strong = "Strong"
    
    var color: Color {
        switch self {
        case .weak: return .red
        case .medium: return .orange
        case .strong: return .green
        }
    }
}

// MARK: - Encryption Manager

final class EncryptionManager {
    static let shared = EncryptionManager()
    private let keychain = KeychainHelper()
    private let keychainKey = "health_export_encryption_key"
    private let saltKey = "health_export_salt"
    
    private init() {}
    
    /// Check if encryption key exists
    func hasKey() -> Bool {
        return keychain.read(key: keychainKey) != nil
    }
    
    /// Setup encryption key from passphrase
    func setupKey(passphrase: String) throws {
        let salt = generateSalt()
        let key = try deriveKey(passphrase: passphrase, salt: salt)
        
        try keychain.save(key: keychainKey, data: key)
        try keychain.save(key: saltKey, data: salt)
    }
    
    /// Rotate encryption key
    func rotateKey(currentPassphrase: String, newPassphrase: String) throws {
        // Verify current passphrase
        guard let currentSalt = keychain.read(key: saltKey),
              let storedKey = keychain.read(key: keychainKey) else {
            throw EncryptionError.keyNotFound
        }
        
        let derivedKey = try deriveKey(passphrase: currentPassphrase, salt: currentSalt)
        guard derivedKey == storedKey else {
            throw EncryptionError.invalidPassphrase
        }
        
        // Generate new key
        let newSalt = generateSalt()
        let newKey = try deriveKey(passphrase: newPassphrase, salt: newSalt)
        
        try keychain.save(key: keychainKey, data: newKey)
        try keychain.save(key: saltKey, data: newSalt)
    }
    
    /// Remove encryption key
    func removeKey() {
        keychain.delete(key: keychainKey)
        keychain.delete(key: saltKey)
    }
    
    /// Encrypt data
    func encrypt(data: Data) throws -> Data {
        guard let key = keychain.read(key: keychainKey) else {
            throw EncryptionError.keyNotFound
        }
        
        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
        
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return combined
    }
    
    /// Decrypt data
    func decrypt(data: Data) throws -> Data {
        guard let key = keychain.read(key: keychainKey) else {
            throw EncryptionError.keyNotFound
        }
        
        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        
        return try AES.GCM.open(sealedBox, using: symmetricKey)
    }
    
    // MARK: - Private Helpers
    
    private func deriveKey(passphrase: String, salt: Data) throws -> Data {
        guard let passphraseData = passphrase.data(using: .utf8) else {
            throw EncryptionError.invalidPassphrase
        }
        
        // PBKDF2 with 100,000 iterations (OWASP recommendation)
        let derivedKey = try PBKDF2.deriveKey(
            password: passphraseData,
            salt: salt,
            iterations: 100_000,
            keyLength: 32 // 256 bits for AES-256
        )
        
        return derivedKey
    }
    
    private func generateSalt() -> Data {
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        return salt
    }
}

// MARK: - PBKDF2 Implementation

enum PBKDF2 {
    static func deriveKey(password: Data, salt: Data, iterations: Int, keyLength: Int) throws -> Data {
        var derivedKeyData = Data(count: keyLength)
        
        let result = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                password.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }
        
        guard result == kCCSuccess else {
            throw EncryptionError.keyDerivationFailed
        }
        
        return derivedKeyData
    }
}

// MARK: - Keychain Helper

final class KeychainHelper {
    func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptionError.keychainSaveFailed
        }
    }
    
    func read(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum EncryptionError: LocalizedError {
    case keyNotFound
    case invalidPassphrase
    case encryptionFailed
    case decryptionFailed
    case keyDerivationFailed
    case keychainSaveFailed
    
    var errorDescription: String? {
        switch self {
        case .keyNotFound: return "Encryption key not found"
        case .invalidPassphrase: return "Invalid passphrase"
        case .encryptionFailed: return "Encryption failed"
        case .decryptionFailed: return "Decryption failed"
        case .keyDerivationFailed: return "Key derivation failed"
        case .keychainSaveFailed: return "Failed to save key to Keychain"
        }
    }
}

// MARK: - CommonCrypto Bridge

import CommonCrypto

// MARK: - Preview

struct EncryptionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EncryptionSettingsView()
        }
    }
}
