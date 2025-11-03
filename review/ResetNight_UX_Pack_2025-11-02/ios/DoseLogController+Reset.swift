import Foundation

extension DoseLogController: DoseLogControllering {
    func resetNight(mode: ResetMode, reason: String, resetBatchId: String) {
        // Implement with a transaction in your SQLite layer.
        // 1) Mark session is_closed_by_reset = 1
        // 2) Write event_log reset_night with payload {mode, reason, reset_batch_id}
        // 3) Soft delete or tag rows with reset_batch_id
        // 4) If mode == .soft, mint a fresh session
    }

    func undoResetNight(resetBatchId: String) {
        // Reverse soft reset by clearing deleted_at or restoring archived rows where reset_batch_id matches
        // No-op for hard reset
    }
}
