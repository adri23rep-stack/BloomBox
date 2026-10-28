//
//  LCTweaksView.swift
//  LiveContainerSwiftUI
//
//  Created by s s on 2024/8/21.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct LCTweakItem : Hashable {
    let fileUrl: URL
    let isFolder: Bool
    let isFramework: Bool
    let isTweak: Bool
    let isEnabled: Bool

    var displayName: String {
        let name = fileUrl.lastPathComponent
        return isEnabled ? name : String(name.dropLast(LCTweakItem.disabledSuffix.count))
    }

    static let disabledSuffix = ".disabled"
}

struct LCTweakFolderView : View {
    @State var baseUrl : URL
    @State var tweakItems : [LCTweakItem]
    private var isRoot : Bool
    @EnvironmentObject private var sharedModel: SharedModel
    
    @State private var errorShow = false
    @State private var errorInfo = ""
    
    // SwiftUI owns the import and naming presentations. Do not present UIKit
    // controllers through SceneDelegate/root while a toolbar Menu is dismissing.
    @State private var showingNamePrompt = false
    @State private var namePromptText = ""
    @State private var itemToRename: LCTweakItem?
    @State private var choosingTweak = false
    
    @State private var isTweakSigning = false
    
    init(baseUrl: URL, isRoot: Bool = false) {
        _baseUrl = State(initialValue: baseUrl)
        self.isRoot = isRoot
        var tmpTweakItems : [LCTweakItem] = []
        let fm = FileManager()
        do {
            let files = try fm.contentsOfDirectory(atPath: baseUrl.path)
            for fileName in files {
                let fileUrl = baseUrl.appendingPathComponent(fileName)
                var isFolder : ObjCBool = false
                fm.fileExists(atPath: fileUrl.path, isDirectory: &isFolder)
                let isEnabled = !fileName.hasSuffix(LCTweakItem.disabledSuffix)
                let baseName = isEnabled ? fileName : String(fileName.dropLast(LCTweakItem.disabledSuffix.count))
                let isFramework = isFolder.boolValue && baseName.hasSuffix(".framework")
                let isTweak = !isFolder.boolValue && baseName.hasSuffix(".dylib")
                tmpTweakItems.append(LCTweakItem(fileUrl: fileUrl, isFolder: isFolder.boolValue, isFramework: isFramework, isTweak: isTweak, isEnabled: isEnabled))
            }
            _tweakItems = State(initialValue: tmpTweakItems)
        } catch {
            NSLog("[LC] failed to load tweaks \(error.localizedDescription)")
            _errorShow = State(initialValue: true)
            _errorInfo = State(initialValue: error.localizedDescription)
            _tweakItems = State(initialValue: [])
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(tweakItems, id:\.self) { tweakItem in
                    HStack {
                        Group {
                            if tweakItem.isFolder && !tweakItem.isFramework {
                                // hidden link so the row navigates without the toggle triggering it
                                ZStack {
                                    NavigationLink {
                                        LCTweakFolderView(baseUrl: tweakItem.fileUrl, isRoot: false)
                                    } label: {
                                        EmptyView()
                                    }
                                    .opacity(0)
                                    HStack {
                                        Label(tweakItem.displayName, systemImage: "folder.fill")
                                        Spacer()
                                        Image(systemName: "chevron.forward")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } else if tweakItem.isFramework {
                                Label(tweakItem.displayName, systemImage: "shippingbox.fill")
                                Spacer()
                            } else if tweakItem.isTweak {
                                Label(tweakItem.displayName, systemImage: "building.columns.fill")
                                Spacer()
                            } else {
                                Label(tweakItem.displayName, systemImage: "document.fill")
                                Spacer()
                            }
                        }
                        .opacity(tweakItem.isEnabled ? 1 : 0.4)
                        if tweakItem.displayName != "TweakLoader.dylib" {
                            Toggle("", isOn: Binding(
                                get: { tweakItem.isEnabled },
                                set: { setTweakEnabled(tweakItem: tweakItem, enabled: $0) }
                            ))
                            .labelsHidden()
                        }
                    }
                    .contextMenu {
                        Button {
                            itemToRename = tweakItem
                            namePromptText = tweakItem.displayName
                            showingNamePrompt = true
                        } label: {
                            Label("lc.common.rename".loc, systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            deleteTweakItem(tweakItem: tweakItem)
                        } label: {
                            Label("lc.common.delete".loc, systemImage: "trash")
                        }
                    }

                }.onDelete { indexSet in
                    deleteTweakItem(indexSet: indexSet)
                }
            } footer: {
                if isRoot {
                    Text("lc.tweakView.globalFolderDesc".loc)
                        .foregroundStyle(.gray)
                        .font(.system(size: 12))
                } else {
                    Text("lc.tweakView.appFolderDesc".loc)
                        .foregroundStyle(.gray)
                        .font(.system(size: 12))
                }
            }
        }
        .navigationTitle(isRoot ? "lc.tabView.tweaks".loc : baseUrl.lastPathComponent)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !isTweakSigning && LCSharedUtils.certificatePassword() != nil {
                    Button {
                        Task { await signAllTweaks() }
                    } label: {
                        Label("sign".loc, systemImage: "signature")
                    }
                }

            }
            ToolbarItem(placement: .topBarTrailing) {
                if !isTweakSigning {
                    Menu {
                        Button {
                            choosingTweak = true
                        } label: {
                            Label("lc.tweakView.importTweak".loc, systemImage: "square.and.arrow.down")
                        }
                        
                        Button {
                            itemToRename = nil
                            namePromptText = ""
                            showingNamePrompt = true
                        } label: {
                            Label("lc.tweakView.newFolder".loc, systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Label("add", systemImage: "plus")
                    }
                } else {
                    ProgressView().progressViewStyle(.circular)
                }

            }
        }
        .alert("lc.common.error".loc, isPresented: $errorShow) {
            Button("lc.common.ok".loc, action: {
            })
        } message: {
            Text(errorInfo)
        }
        .alert(itemToRename == nil ? "lc.common.enterNewFolderName".loc : "lc.common.enterNewName".loc,
               isPresented: $showingNamePrompt) {
            TextField("lc.common.enterNewName".loc, text: $namePromptText)
            Button("lc.common.cancel".loc, role: .cancel) {
                itemToRename = nil
            }
            Button("lc.common.ok".loc) {
                if let item = itemToRename {
                    renameTweakItem(tweakItem: item, to: namePromptText)
                } else {
                    createNewFolder(named: namePromptText)
                }
                itemToRename = nil
            }
        }
        .fileImporter(isPresented: $choosingTweak,
                      allowedContentTypes: [.dylib, .lcFramework],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let fileURLs):
                Task { await startInstallTweak(fileURLs) }
            case .failure(let error):
                errorInfo = error.localizedDescription
                errorShow = true
            }
        }
    }
    
    func setTweakEnabled(tweakItem: LCTweakItem, enabled: Bool) {
        if tweakItem.isEnabled == enabled {
            return
        }
        let displayName = tweakItem.displayName
        let newName = enabled ? displayName : displayName + LCTweakItem.disabledSuffix
        let newUrl = baseUrl.appendingPathComponent(newName)
        let fm = FileManager()
        do {
            try fm.moveItem(at: tweakItem.fileUrl, to: newUrl)
        } catch {
            errorShow = true
            errorInfo = error.localizedDescription
            return
        }
        guard let index = tweakItems.firstIndex(of: tweakItem) else {
            return
        }
        tweakItems[index] = LCTweakItem(fileUrl: newUrl, isFolder: tweakItem.isFolder, isFramework: tweakItem.isFramework, isTweak: tweakItem.isTweak, isEnabled: enabled)
    }

    func deleteTweakItem(indexSet: IndexSet) {
        var indexToRemove : [Int] = []
        let fm = FileManager()
        do {
            for i in indexSet {
                let tweakItem = tweakItems[i]
                try fm.removeItem(at: tweakItem.fileUrl)
                indexToRemove.append(i)
            }
        } catch {
            errorShow = true
            errorInfo = error.localizedDescription
            return
        }
        if isRoot {
            for iToRemove in indexToRemove {
                sharedModel.tweakFolderNames.removeAll(where: { s in
                    return s == tweakItems[iToRemove].displayName
                })
            }
        }

        tweakItems.remove(atOffsets: IndexSet(indexToRemove))
    }

    func deleteTweakItem(tweakItem: LCTweakItem) {
        var indexToRemove : Int?
        let fm = FileManager()
        do {

            try fm.removeItem(at: tweakItem.fileUrl)
            indexToRemove = tweakItems.firstIndex(where: { s in
                return s == tweakItem
            })
        } catch {
            errorShow = true
            errorInfo = error.localizedDescription
            return
        }

        guard let indexToRemove = indexToRemove else {
            return
        }
        tweakItems.remove(at: indexToRemove)
        if isRoot {
            sharedModel.tweakFolderNames.removeAll(where: { s in
                return s == tweakItem.displayName
            })
        }
    }
    
    func validTweakName(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..",
              !name.contains("/"), !name.contains("\\") else {
            errorInfo = "El nombre no puede estar vacío ni contener rutas."
            errorShow = true
            return nil
        }
        return name
    }

    func renameTweakItem(tweakItem: LCTweakItem, to rawName: String) {
        guard let newName = validTweakName(rawName),
              let indexToRename = tweakItems.firstIndex(of: tweakItem) else {
            return
        }
        let newFileName = tweakItem.isEnabled ? newName : newName + LCTweakItem.disabledSuffix
        let newUrl = baseUrl.appendingPathComponent(newFileName)
        if tweakItem.fileUrl == newUrl { return }
        do {
            try FileManager.default.moveItem(at: tweakItem.fileUrl, to: newUrl)
        } catch {
            errorInfo = error.localizedDescription
            errorShow = true
            return
        }
        tweakItems[indexToRename] = LCTweakItem(
            fileUrl: newUrl, isFolder: tweakItem.isFolder,
            isFramework: tweakItem.isFramework, isTweak: tweakItem.isTweak,
            isEnabled: tweakItem.isEnabled
        )
        if isRoot && tweakItem.isFolder && !tweakItem.isFramework,
           let index = sharedModel.tweakFolderNames.firstIndex(of: tweakItem.displayName) {
            sharedModel.tweakFolderNames[index] = newName
        }
    }

    func signAllTweaks() async {
        do {
            defer {
                isTweakSigning = false
            }
            
            try await LCUtils.signTweaks(tweakFolderUrl: self.baseUrl, force: true) { p in
                isTweakSigning = true
            }

        } catch {
            errorInfo = error.localizedDescription
            errorShow = true
            return
        }
    }
    
    func createNewFolder(named rawName: String) {
        guard let name = validTweakName(rawName) else { return }
        let dest = baseUrl.appendingPathComponent(name, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: false)
        } catch {
            errorInfo = error.localizedDescription
            errorShow = true
            return
        }
        tweakItems.append(LCTweakItem(fileUrl: dest, isFolder: true, isFramework: false, isTweak: false, isEnabled: true))
        if isRoot && !sharedModel.tweakFolderNames.contains(name) {
            sharedModel.tweakFolderNames.append(name)
        }
    }

    @MainActor
    func startInstallTweak(_ urls: [URL]) async {
        let fm = FileManager.default
        for fileUrl in urls {
            let scoped = fileUrl.startAccessingSecurityScopedResource()
            defer { if scoped { fileUrl.stopAccessingSecurityScopedResource() } }
            do {
                guard fileUrl.isFileURL else {
                    throw "lc.tweakView.notFileError %@".localizeWithFormat(fileUrl.lastPathComponent)
                }
                let fileName = fileUrl.lastPathComponent
                let isFramework = fileName.lowercased().hasSuffix(".framework")
                let isTweak = fileName.lowercased().hasSuffix(".dylib")
                guard isFramework || isTweak else {
                    throw "Solo se pueden importar archivos .dylib o carpetas .framework."
                }
                let destination = baseUrl.appendingPathComponent(fileName)
                guard !fm.fileExists(atPath: destination.path) else {
                    throw "Ya existe un archivo o carpeta con el nombre \\(fileName)."
                }
                // The Files picker may return a security-scoped, temporary copy.
                // Never move/delete the user's original file in Files.
                try fm.copyItem(at: fileUrl, to: destination)
                if isTweak {
                    LCParseMachO((destination.path as NSString).utf8String, false) { path, header, _, _ in
                        LCPatchAddRPath(path, header)
                    }
                }
                tweakItems.append(LCTweakItem(
                    fileUrl: destination, isFolder: isFramework,
                    isFramework: isFramework, isTweak: isTweak, isEnabled: true
                ))
            } catch {
                errorInfo = error.localizedDescription
                errorShow = true
            }
        }
    }
}

struct LCTweaksView: View {
    var body: some View {
        NavigationView {
            LCTweakFolderView(baseUrl: LCPath.tweakPath, isRoot: true)
        }
        .navigationViewStyle(StackNavigationViewStyle())

    }
}
