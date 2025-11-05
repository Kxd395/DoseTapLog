import Foundation
import Compression

/// Gzip compression for health exports
/// Ensures consistent compression format across iOS/Node.js
extension HealthExportBridge {
    
    /// Compress JSONL file to .jsonl.gz format
    /// - Parameter jsonlURL: Path to uncompressed .jsonl file
    /// - Returns: Path to compressed .jsonl.gz file
    func compressExport(jsonlURL: URL) throws -> URL {
        let gzURL = jsonlURL.deletingPathExtension().appendingPathExtension("jsonl.gz")
        
        // Read source data
        let sourceData = try Data(contentsOf: jsonlURL)
        
        // Compress using Apple's Compression framework (compatible with gzip)
        guard let compressedData = sourceData.compress(using: .zlib) else {
            throw ExportError.compressionFailed
        }
        
        // Write compressed data
        try compressedData.write(to: gzURL, options: .atomic)
        
        // Delete uncompressed file (optional - can keep for debugging)
        try? FileManager.default.removeItem(at: jsonlURL)
        
        return gzURL
    }
    
    /// Decompress .jsonl.gz file (for testing/verification)
    /// - Parameter gzURL: Path to compressed file
    /// - Returns: Decompressed data
    func decompressExport(gzURL: URL) throws -> Data {
        let compressedData = try Data(contentsOf: gzURL)
        
        guard let decompressed = compressedData.decompress(using: .zlib) else {
            throw ExportError.decompressionFailed
        }
        
        return decompressed
    }
}

// MARK: - Data Compression Extension

extension Data {
    /// Compress data using specified algorithm
    func compress(using algorithm: Algorithm) -> Data? {
        return withUnsafeBytes { (sourcePtr: UnsafeRawBufferPointer) -> Data? in
            let sourceBuffer = sourcePtr.baseAddress!
            let sourceSize = count
            
            // Estimate destination size (worst case: source size + overhead)
            let destSize = sourceSize + 1024
            var destBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destSize)
            defer { destBuffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(
                destBuffer,
                destSize,
                sourceBuffer.assumingMemoryBound(to: UInt8.self),
                sourceSize,
                nil,
                algorithm.compressionAlgorithm
            )
            
            guard compressedSize > 0 else { return nil }
            
            return Data(bytes: destBuffer, count: compressedSize)
        }
    }
    
    /// Decompress data using specified algorithm
    func decompress(using algorithm: Algorithm) -> Data? {
        return withUnsafeBytes { (sourcePtr: UnsafeRawBufferPointer) -> Data? in
            let sourceBuffer = sourcePtr.baseAddress!
            let sourceSize = count
            
            // Estimate destination size (assume 10x compression ratio)
            let destSize = sourceSize * 10
            var destBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destSize)
            defer { destBuffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                destBuffer,
                destSize,
                sourceBuffer.assumingMemoryBound(to: UInt8.self),
                sourceSize,
                nil,
                algorithm.compressionAlgorithm
            )
            
            guard decompressedSize > 0 else { return nil }
            
            return Data(bytes: destBuffer, count: decompressedSize)
        }
    }
    
    enum Algorithm {
        case zlib  // Compatible with gzip
        case lzfse // Apple's proprietary (faster, but not cross-platform)
        
        var compressionAlgorithm: compression_algorithm {
            switch self {
            case .zlib: return COMPRESSION_ZLIB
            case .lzfse: return COMPRESSION_LZFSE
            }
        }
    }
}

// MARK: - Errors

extension HealthExportBridge {
    enum ExportError: Error, LocalizedError {
        case compressionFailed
        case decompressionFailed
        case invalidFormat
        
        var errorDescription: String? {
            switch self {
            case .compressionFailed: return "Failed to compress export"
            case .decompressionFailed: return "Failed to decompress export"
            case .invalidFormat: return "Invalid export format"
            }
        }
    }
}

// MARK: - Integration with Main Exporter

extension HealthExportBridge {
    
    /// Export with compression
    func exportIncrementalCompressed(cutoffHourLocal: Int = 12) async throws -> URL {
        // Export to JSONL
        let jsonlURL = try await exportIncremental(cutoffHourLocal: cutoffHourLocal)
        
        // Compress to .jsonl.gz
        let gzURL = try compressExport(jsonlURL: jsonlURL)
        
        return gzURL
    }
}
