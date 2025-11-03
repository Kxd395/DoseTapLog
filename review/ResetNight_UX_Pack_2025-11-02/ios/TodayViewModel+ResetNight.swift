import Foundation

extension TodayViewModel {

    func presentResetNight() {
        self.showResetSheet = true
    }

    func performResetNight(mode: ResetMode, reason: String) {
        let batchId = UUID().uuidString
        controller.resetNight(mode: mode, reason: reason, resetBatchId: batchId)
        controller.endLiveActivity()
        controller.cancelDose2Notifications()
        self.nightKey = nil
        self.dose1TimeUTC = nil
        self.dose2TimeUTC = nil
        self.finalWakeTimeUTC = nil
        self.lastEvents.removeAll()
        self.pendingResetBatchId = batchId
        self.showUndoResetBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            self.showUndoResetBanner = false
            self.pendingResetBatchId = nil
        }
    }

    func undoResetNight() {
        guard let batch = self.pendingResetBatchId else { return }
        controller.undoResetNight(resetBatchId: batch)
        self.pendingResetBatchId = nil
        self.showUndoResetBanner = false
        self.onAppear()
    }
}
