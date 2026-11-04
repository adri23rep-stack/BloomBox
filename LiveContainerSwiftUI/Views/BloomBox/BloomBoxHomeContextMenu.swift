import SwiftUI

/// Host-independent Home app menu. It only sees actions and display state:
/// LiveContainer/SideStore model ownership remains with the caller's adapter.
struct BloomBoxHomeContextMenu: View {
    struct Folder: Identifiable {
        let id: String
        let name: String
    }

    struct State {
        let isRunning: Bool
        let isSigning: Bool
        let isSideStore: Bool
        let isFavorite: Bool
        let isInDock: Bool
        let dockHasSpace: Bool
        let isInFolder: Bool
        let networkBlocked: Bool
        let pageIndices: [Int]
        let folders: [Folder]
        let categories: [String]
    }

    struct Actions {
        let launch: () -> Void
        let launchJIT: (() -> Void)?
        let editHome: () -> Void
        let rename: () -> Void
        let changeIcon: () -> Void
        let toggleFavorite: () -> Void
        let moveToHome: () -> Void
        let moveToDock: () -> Void
        let moveToPage: (Int) -> Void
        let newPage: () -> Void
        let newFolder: () -> Void
        let moveToFolder: (String) -> Void
        let removeFromFolder: () -> Void
        let setCategory: (String?) -> Void
        let newCategory: () -> Void
        let toggleNetwork: () -> Void
        let addTweak: () -> Void
        let settings: () -> Void
        let uninstall: () -> Void
        let removeFromHome: () -> Void
    }

    let state: State
    let actions: Actions

    var body: some View {
        Group {
            launchActions
            organizationActions
            guestActions
        }
    }

    @ViewBuilder private var launchActions: some View {
        Button("Abrir", systemImage: "play.fill", action: actions.launch)
            .disabled(state.isRunning || state.isSigning)
        if let jit = actions.launchJIT {
            Button("Abrir con JIT", systemImage: "bolt.fill", action: jit)
                .disabled(state.isSideStore)
        }
        Button("Editar escritorio", systemImage: "square.grid.3x3",
               action: actions.editHome)
        Button("Renombrar", systemImage: "pencil", action: actions.rename)
        Button("Cambiar icono", systemImage: "photo", action: actions.changeIcon)
        Button(state.isFavorite ? "Quitar favorito" : "Favorito", systemImage: "star",
               action: actions.toggleFavorite)
    }

    @ViewBuilder private var organizationActions: some View {
        if state.isInDock {
            Button("Sacar del Dock", systemImage: "rectangle.bottomthird.inset.filled",
                   action: actions.moveToHome)
        } else if state.dockHasSpace {
            Button("Añadir al Dock", systemImage: "rectangle.bottomthird.inset.filled",
                   action: actions.moveToDock)
        }
        Menu("Mover a página", systemImage: "rectangle.on.rectangle") {
            ForEach(state.pageIndices, id: \.self) { index in
                Button("Página \(index + 1)") { actions.moveToPage(index) }
            }
            Button("Nueva página", action: actions.newPage)
        }
        Menu("Carpeta", systemImage: "folder") {
            Button("Nueva carpeta", action: actions.newFolder)
            ForEach(state.folders) { folder in
                Button(folder.name) { actions.moveToFolder(folder.id) }
            }
            if state.isInFolder {
                Button("Sacar de carpeta", action: actions.removeFromFolder)
            }
        }
        Menu("Categoría", systemImage: "tag") {
            ForEach(state.categories, id: \.self) { name in
                Button(name) { actions.setCategory(name) }
            }
            Button("Nueva categoría…", action: actions.newCategory)
            Button("Sin categoría") { actions.setCategory(nil) }
        }
    }

    @ViewBuilder private var guestActions: some View {
        Button(state.networkBlocked ? "Permitir Internet" : "Bloquear Internet (experimental)",
               systemImage: state.networkBlocked ? "wifi" : "wifi.slash",
               action: actions.toggleNetwork)
            .disabled(state.isRunning)
        Button("Añadir Tweak", systemImage: "square.and.arrow.down.on.square",
               action: actions.addTweak)
            .disabled(state.isSigning)
        Button("Ajustes de LiveContainer", systemImage: "gearshape",
               action: actions.settings)
        Button("Desinstalar app", systemImage: "trash", role: .destructive,
               action: actions.uninstall)
            .disabled(state.isRunning || state.isSigning)
        Button("Quitar del escritorio", systemImage: "minus.circle", role: .destructive,
               action: actions.removeFromHome)
    }
}
