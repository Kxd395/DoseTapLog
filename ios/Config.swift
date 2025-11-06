import Foundation

enum Config {
    // MARK: - Dosing Parameters
    static let defaultBedtimeHour: Int = 23
    static let defaultBedtimeMinute: Int = 30
    static let defaultTotalGrams: Double = 6.5
    static let perDoseMinG: Double = 1.5
    static let perDoseMaxG: Double = 4.5
    static let totalNightMinG: Double = 3.0
    static let totalNightMaxG: Double = 9.0
    static let splitMinPercentFirst: Double = 40.0
    static let splitMaxPercentFirst: Double = 60.0
    static let windowStartMinAfterDose1: Int = 150
    static let windowEndMinAfterDose1: Int = 240
    
    // MARK: - WHOOP OAuth2 Integration
    // Registered: 2025-11-05
    // Developer Portal: https://developer.whoop.com/
    // Credentials stored in: docs/SECRETS.md (client_secret NEVER in this file)
    
    /// WHOOP OAuth2 Client ID (PUBLIC - safe to commit)
    static let whoopClientId = "6b7c7936-ecfc-489f-8b80-0cffb303af9e"
    
    /// OAuth2 Redirect URI (registered with WHOOP)
    static let whoopRedirectUri = "dosetrack://oauth/whoop/callback"
    
    /// OAuth2 Scopes (recovery + sleep data)
    static let whoopScopes = "read:recovery read:sleep"
    
    /// Backend OAuth Proxy URL
    /// Update production URL after deploying backend to Railway/Cloud Functions
    #if DEBUG
    static let whoopProxyURL = "http://localhost:3000/whoop" // Local development
    #else
    static let whoopProxyURL = "https://YOUR_BACKEND_URL/whoop" // TODO: Update after deployment
    #endif
    
    /// WHOOP OAuth Authorization URL (computed)
    static var whoopAuthorizationURL: String {
        let clientId = whoopClientId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? whoopClientId
        let redirectUri = whoopRedirectUri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? whoopRedirectUri
        let scopes = whoopScopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? whoopScopes
        
        return "https://api.prod.whoop.com/oauth/oauth2/auth?client_id=\(clientId)&redirect_uri=\(redirectUri)&response_type=code&scope=\(scopes)"
    }
}

