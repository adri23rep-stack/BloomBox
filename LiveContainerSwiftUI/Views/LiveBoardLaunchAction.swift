import Foundation

// Shared UI preflight extracted from LCAppBannerViewController. The runtime stays in runApp.
extension LCAppModel {
    @MainActor
    func launchFromLibrary(multitask: Bool? = nil, reuseExistingWindow: Bool = true, forceJIT: Bool = false) async throws {
        if appInfo.isLocked && !DataManager.shared.model.isHiddenAppUnlocked {
            guard try await LCUtils.authenticateUser() else { return }
        }
        if #available(iOS 16.0, *), reuseExistingWindow,
           let folder = uiSelectedContainer?.folderName,
           MultitaskManager.isUsing(container: folder) {
            // Reopening a running guest does not run the JIT attach again.
            // Tell the user to close the guest instead of appearing to ignore the button.
            guard BloomBoxJITLaunchGuard.mayReuseWindow(requestedJIT: forceJIT) else {
                throw "Esta app ya está abierta en LiveProcess. Ciérrala desde la multitarea y vuelve a elegir Launch with JIT."
            }
            var found = false
            if #available(iOS 16.1, *) {
                found = MultitaskWindowManager.openExistingAppWindow(dataUUID: folder)
            }
            if !found { found = MultitaskDockManager.shared.bringMultitaskViewToFront(uuid: folder) }
            if found { return }
        }
        try await runApp(multitask: multitask, forceJIT: forceJIT ? true : nil)
    }
}
