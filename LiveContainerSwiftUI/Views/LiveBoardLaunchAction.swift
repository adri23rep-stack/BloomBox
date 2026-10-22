import Foundation

// Shared UI preflight extracted from LCAppBannerViewController. The runtime stays in runApp.
extension LCAppModel {
    @MainActor
    func launchFromLibrary(multitask: Bool? = nil, reuseExistingWindow: Bool = true, forceJIT: Bool = false) async throws {
        if #available(iOS 16.0, *), reuseExistingWindow,
           let folder = uiSelectedContainer?.folderName,
           MultitaskManager.isUsing(container: folder) {
            var found = false
            if #available(iOS 16.1, *) {
                found = MultitaskWindowManager.openExistingAppWindow(dataUUID: folder)
            }
            if !found { found = MultitaskDockManager.shared.bringMultitaskViewToFront(uuid: folder) }
            if found { return }
        }
        if appInfo.isLocked && !DataManager.shared.model.isHiddenAppUnlocked {
            guard try await LCUtils.authenticateUser() else { return }
        }
        try await runApp(multitask: multitask, forceJIT: forceJIT ? true : nil)
    }
}
