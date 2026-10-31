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
            Section("Archivos temporales · Detalle") {
                if let breakdown = model.breakdown {
                    if breakdown.temporaryEntries.isEmpty {
                        Text("No se encontraron archivos temporales.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(breakdown.temporaryEntries.prefix(20))) { entry in
                            HStack(spacing: 12) {
                                Text(entry.name)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                Spacer(minLength: 12)
                                Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        if breakdown.temporaryEntries.count > 20 {
                            Text("Mostrando los 20 elementos más grandes de \\(breakdown.temporaryEntries.count).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("Último análisis: \\(breakdown.scannedAt.formatted(date: .omitted, time: .standard)). Los temporales pueden desaparecer mientras usas la app. Actualiza para volver a medir.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if model.isCalculating {
                    ProgressView("Analizando archivos temporales…")
                }
            }
            Section {
                NavigationLink {
                    LCDataManagementView()
                } label: {
                    Label("Gestionar temporales y cachés (con confirmación)", systemImage: "trash")
                }
            } footer: {
                Text("Abrir el administrador no borra nada. Las opciones de borrar temporales, cachés y otros datos son independientes.")
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
