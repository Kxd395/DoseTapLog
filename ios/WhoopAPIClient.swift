//
//  WhoopAPIClient.swift
//  DoseTrack
//
//  Created: November 5, 2025
//  Purpose: API client for WHOOP OAuth proxy backend
//  Security: Communicates with OAuth proxy, never stores access_token directly
//

import Foundation

/// API client for WHOOP OAuth2 integration
/// Communicates with DoseTrack OAuth proxy backend for secure token management
class WhoopAPIClient {
    static let shared = WhoopAPIClient()
    
    private let baseURL: String
    private let session: URLSession
    
    // MARK: - Initialization
    
    private init() {
        self.baseURL = Config.whoopProxyURL
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - OAuth Flow
    
    /// Exchange OAuth authorization code for session ID
    /// - Parameter code: Authorization code from OAuth redirect
    /// - Returns: Session ID to store in UserDefaults
    /// - Throws: WhoopError if exchange fails
    func exchangeCode(_ code: String) async throws -> WhoopSession {
        let url = URL(string: "\(baseURL)/oauth/exchange")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "code": code,
            "redirect_uri": Config.whoopRedirectUri
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhoopError.networkError("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 200:
            let result = try JSONDecoder().decode(ExchangeResponse.self, from: data)
            return WhoopSession(
                sessionId: result.sessionId,
                whoopUserId: result.whoopUserId,
                expiresAt: ISO8601DateFormatter().date(from: result.expiresAt) ?? Date().addingTimeInterval(3600),
                scopes: result.scopes
            )
        case 400:
            throw WhoopError.invalidCode
        case 401:
            throw WhoopError.unauthorized
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WhoopError.networkError("Exchange failed: \(errorMessage)")
        }
    }
    
    // MARK: - Data Fetching
    
    /// Fetch WHOOP recovery data for a date range
    /// - Parameters:
    ///   - sessionId: Session ID from exchangeCode()
    ///   - start: Start date (inclusive)
    ///   - end: End date (inclusive)
    /// - Returns: Array of recovery records
    /// - Throws: WhoopError if fetch fails
    func fetchRecovery(sessionId: String, start: Date, end: Date) async throws -> [RecoveryRecord] {
        let url = URL(string: "\(baseURL)/data/recovery")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(sessionId)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let formatter = ISO8601DateFormatter()
        let body: [String: Any] = [
            "start": formatter.string(from: start),
            "end": formatter.string(from: end)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Retry logic for transient failures
        return try await retryWithBackoff(maxAttempts: 3) {
            let (data, response) = try await self.session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WhoopError.networkError("Invalid response")
            }
            
            switch httpResponse.statusCode {
            case 200:
                let result = try JSONDecoder().decode(RecoveryResponse.self, from: data)
                return result.records.map { record in
                    RecoveryRecord(
                        date: ISO8601DateFormatter().date(from: record.createdAt) ?? Date(),
                        cycleId: record.cycleId,
                        sleepId: record.sleepId,
                        recoveryScore: record.score.recoveryScore,
                        hrvRmssd: record.score.hrvRmssd,
                        restingHR: record.score.restingHeartRate,
                        spo2: record.score.spo2,
                        skinTemp: record.score.skinTemp
                    )
                }
            case 401:
                // Token expired or session invalid
                throw WhoopError.sessionExpired
            case 404:
                // User revoked access on WHOOP side
                throw WhoopError.accessRevoked
            case 429:
                // Rate limited
                throw WhoopError.rateLimited
            default:
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw WhoopError.networkError("Fetch failed: \(errorMessage)")
            }
        }
    }
    
    /// Fetch WHOOP sleep data for a specific sleep ID
    /// - Parameters:
    ///   - sessionId: Session ID from exchangeCode()
    ///   - sleepId: WHOOP sleep ID from recovery record
    /// - Returns: Sleep record with end time for service day mapping
    /// - Throws: WhoopError if fetch fails
    func fetchSleep(sessionId: String, sleepId: String) async throws -> SleepRecord {
        let url = URL(string: "\(baseURL)/data/sleep")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(sessionId)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Fetch sleep by ID (backend will filter)
        let formatter = ISO8601DateFormatter()
        let now = Date()
        let past30Days = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let body: [String: Any] = [
            "start": formatter.string(from: past30Days),
            "end": formatter.string(from: now)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhoopError.networkError("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 200:
            let result = try JSONDecoder().decode(SleepResponse.self, from: data)
            guard let record = result.records.first(where: { $0.id == sleepId }) else {
                throw WhoopError.notFound
            }
            return SleepRecord(
                id: record.id,
                start: ISO8601DateFormatter().date(from: record.start) ?? Date(),
                end: ISO8601DateFormatter().date(from: record.end) ?? Date(),
                durationMinutes: record.score.sleepDuration
            )
        case 401:
            throw WhoopError.sessionExpired
        case 404:
            throw WhoopError.notFound
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WhoopError.networkError("Sleep fetch failed: \(errorMessage)")
        }
    }
    
    /// Revoke WHOOP access and delete session
    /// - Parameter sessionId: Session ID to revoke
    /// - Throws: WhoopError if revoke fails
    func revokeAccess(sessionId: String) async throws {
        let url = URL(string: "\(baseURL)/oauth/revoke")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(sessionId)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhoopError.networkError("Invalid response")
        }
        
        // Accept 200 or 401 (already revoked)
        if httpResponse.statusCode != 200 && httpResponse.statusCode != 401 {
            throw WhoopError.revokeFailed
        }
    }
    
    // MARK: - Retry Logic
    
    /// Retry a network request with exponential backoff
    /// - Parameters:
    ///   - maxAttempts: Maximum retry attempts (default: 3)
    ///   - operation: Async operation to retry
    /// - Returns: Result of operation
    /// - Throws: Last error encountered
    private func retryWithBackoff<T>(
        maxAttempts: Int = 3,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch let error as WhoopError {
                lastError = error
                
                // Don't retry on certain errors
                switch error {
                case .sessionExpired, .accessRevoked, .invalidCode, .unauthorized:
                    throw error
                case .rateLimited:
                    // Exponential backoff for rate limiting
                    let delay = pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                case .networkError, .fetchFailed, .revokeFailed, .notFound:
                    // Retry transient errors
                    if attempt < maxAttempts {
                        let delay = pow(2.0, Double(attempt - 1))
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                }
            } catch {
                lastError = error
                // Retry unknown errors
                if attempt < maxAttempts {
                    let delay = pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? WhoopError.networkError("Unknown error")
    }
}

// MARK: - Models

/// WHOOP session metadata
struct WhoopSession: Codable {
    let sessionId: String
    let whoopUserId: Int
    let expiresAt: Date
    let scopes: [String]
}

/// WHOOP recovery record (for display and export)
struct RecoveryRecord: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let cycleId: Int
    let sleepId: String
    let recoveryScore: Double // 0-100
    let hrvRmssd: Double // milliseconds
    let restingHR: Double // bpm
    let spo2: Double? // percentage
    let skinTemp: Double? // celsius
    
    enum CodingKeys: String, CodingKey {
        case date, cycleId, sleepId, recoveryScore, hrvRmssd, restingHR, spo2, skinTemp
    }
}

/// WHOOP sleep record (for service day mapping)
struct SleepRecord: Codable {
    let id: String
    let start: Date
    let end: Date
    let durationMinutes: Int
}

// MARK: - Error Types

enum WhoopError: LocalizedError {
    case invalidCode
    case unauthorized
    case sessionExpired
    case accessRevoked
    case rateLimited
    case notFound
    case fetchFailed
    case revokeFailed
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Invalid authorization code. Please try connecting again."
        case .unauthorized:
            return "WHOOP authentication failed. Please check your credentials."
        case .sessionExpired:
            return "Your WHOOP session has expired. Please reconnect."
        case .accessRevoked:
            return "WHOOP access has been revoked. Please reconnect to continue."
        case .rateLimited:
            return "Too many requests. Please try again in a few minutes."
        case .notFound:
            return "Requested data not found."
        case .fetchFailed:
            return "Failed to fetch WHOOP data. Please try again."
        case .revokeFailed:
            return "Failed to disconnect from WHOOP. Please try again."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - API Response Models

private struct ExchangeResponse: Codable {
    let sessionId: String
    let whoopUserId: Int
    let expiresAt: String
    let scopes: [String]
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case whoopUserId = "whoop_user_id"
        case expiresAt = "expires_at"
        case scopes
    }
}

private struct RecoveryResponse: Codable {
    let records: [RecoveryRecordAPI]
}

private struct RecoveryRecordAPI: Codable {
    let cycleId: Int
    let sleepId: String
    let createdAt: String
    let score: RecoveryScoreAPI
    
    enum CodingKeys: String, CodingKey {
        case cycleId = "cycle_id"
        case sleepId = "sleep_id"
        case createdAt = "created_at"
        case score
    }
}

private struct RecoveryScoreAPI: Codable {
    let recoveryScore: Double
    let hrvRmssd: Double
    let restingHeartRate: Double
    let spo2: Double?
    let skinTemp: Double?
    
    enum CodingKeys: String, CodingKey {
        case recoveryScore = "recovery_score"
        case hrvRmssd = "hrv_rmssd_milli"
        case restingHeartRate = "resting_heart_rate"
        case spo2 = "spo2_percentage"
        case skinTemp = "skin_temp_celsius"
    }
}

private struct SleepResponse: Codable {
    let records: [SleepRecordAPI]
}

private struct SleepRecordAPI: Codable {
    let id: String
    let start: String
    let end: String
    let score: SleepScoreAPI
}

private struct SleepScoreAPI: Codable {
    let sleepDuration: Int
    
    enum CodingKeys: String, CodingKey {
        case sleepDuration = "total_in_bed_time_milli"
    }
}
