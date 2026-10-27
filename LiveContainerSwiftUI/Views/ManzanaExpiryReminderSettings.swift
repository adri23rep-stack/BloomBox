import SwiftUI

@available(iOS 16.2, *)
struct ManzanaExpiryReminderSettings: View {
    @ObservedObject private var center = ManzanaExpiryReminderCenter.shared

    var body: some View {
        Form {
            Section {
                Toggle("Contador de caducidad (8 horas)", isOn: Binding(
                    get: { center.enabled },
                    set: { center.setEnabled($0) }
                ))
                Label("Isla Dinámica · últimas 8 horas", systemImage: "clock")
                Label("Notificación · última hora", systemImage: "bell")
            } header: {
                Text("SideStore")
            } footer: {
                Text("Al activarlo, Manzana intenta programar una Live Activity que empezará cuando falten ocho horas para la caducidad de la primera app. iOS controla si la Isla Dinámica se muestra.")
            }

            Section("Probar Isla Dinámica") {
                Button {
                    Task { await center.startDemo() }
                } label: {
                    Label("Probar Isla Dinámica (3 minutos)", systemImage: "play.circle.fill")
                }
                .disabled(center.demonstrationActive)

                if center.demonstrationActive {
                    Button(role: .destructive) {
                        Task { await center.stopDemo() }
                    } label: {
                        Label("Detener prueba", systemImage: "stop.circle.fill")
                    }
                }

                Text(center.demoMessage)
                    .font(.footnote)
                    .textSelection(.enabled)
                Text("La prueba crea un contador real de tres minutos, independiente de las fechas de SideStore. No cambia la caducidad de ninguna app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Próximo vencimiento") {
                if let expiration = center.nearestExpiration {
                    LabeledContent("Caducidad", value: expiration.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Aplicaciones próximas", value: "\(center.appCount)")
                } else {
                    Text("No se han detectado fechas todavía.").foregroundStyle(.secondary)
                }
                Text(center.status).font(.footnote).textSelection(.enabled)
                if let last = center.snapshotDate {
                    Text("Datos de SideStore actualizados: \(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Actualizar fechas y recordatorios") {
                    Task { await center.synchronize() }
                }
                Button("Abrir SideStore") {
                    if let url = URL(string: "sidestore://") {
                        UIApplication.shared.open(url)
                    }
                }
            }

            Section {
                Text("Las fechas proceden de widget_data.json, publicado por SideStore en el App Group compartido. Manzana no modifica su base de datos ni refresca las firmas automáticamente.")
                    .font(.footnote)
                Text("Al refrescar tus apps, vuelve a Manzana para sincronizar la nueva fecha y cancelar el contador anterior. Si faltan datos, la función no inventará fechas.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Caducidad · Isla Dinámica")
        .navigationBarTitleDisplayMode(.inline)
        .task { await center.synchronize() }
    }
}
