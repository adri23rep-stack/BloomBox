import Foundation
import SwiftUI

struct LCStorageManagementView: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @StateObject private var model = LCStorageManagementModel()
    @State private var refreshed: Bool = false

    var body: some View {
        Form {
            LCStorageSummarySection(
                breakdown: model.breakdown,
                isCalculating: model.isCalculating,
                errorInfo: model.errorInfo
            )
            LCInstalledAppsSection(breakdown: model.breakdown)
            Section {
                NavigationLink {
                    LCDataManagementView()
                } label: {
                    Label("Limpiar cachés (con confirmación)", systemImage: "trash")
                }
            } footer: {
                Text("Abrir el administrador no borra nada. Revisa qué se eliminará antes de confirmar.")
            }
        }
        .navigationTitle("lc.settings.storageManagement".loc)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refresh() }
                } label: {
                    Label("Actualizar tamaños", systemImage: "arrow.clockwise")
                }
                .disabled(model.isCalculating)
                .accessibilityIdentifier("bloombox.storage.refresh")
            }
        }
        .task {
            if !refreshed {
                await refresh()
                refreshed = true
            }

        }
    }

    private func refresh() async {
        await model.refresh(apps: sharedModel.apps, hiddenApps: sharedModel.hiddenApps)
    }
}
