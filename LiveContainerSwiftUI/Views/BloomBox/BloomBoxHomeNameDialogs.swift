import SwiftUI

/// Home rename and folder-creation prompts independent of the host app model.
/// The caller owns persistence, folders, guest app names and reconciliation.
struct BloomBoxHomeNameDialogs: ViewModifier {
    @Binding var renameKey: String?
    @Binding var renameValue: String
    @Binding var newFolderKey: String?
    @Binding var folderName: String
    let englishUI: Bool
    let onRename: (String, String) -> Void
    let onCreateFolder: (String, String) -> Void

    func body(content: Content) -> some View {
        content
            .alert(englishUI ? "Rename" : "Renombrar",
                   isPresented: Binding(
                    get: { renameKey != nil },
                    set: { if !$0 { renameKey = nil } }
                   )) {
                TextField(englishUI ? "Name" : "Nombre", text: $renameValue)
                Button(englishUI ? "Cancel" : "Cancelar", role: .cancel) {
                    renameKey = nil
                }
                Button(englishUI ? "Save" : "Guardar") {
                    if let key = renameKey {
                        onRename(key, renameValue.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    renameKey = nil
                }
            }
            .alert(englishUI ? "New Folder" : "Nueva carpeta",
                   isPresented: Binding(
                    get: { newFolderKey != nil },
                    set: { if !$0 { newFolderKey = nil } }
                   )) {
                TextField(englishUI ? "Folder name" : "Nombre de carpeta",
                          text: $folderName)
                Button(englishUI ? "Cancel" : "Cancelar", role: .cancel) {
                    newFolderKey = nil
                }
                Button(englishUI ? "Create" : "Crear") {
                    if let key = newFolderKey {
                        let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
                        onCreateFolder(key, name.isEmpty ? (englishUI ? "Apps" : "Apps") : name)
                    }
                    newFolderKey = nil
                }
            }
    }
}
