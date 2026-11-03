import SwiftUI

/// BloomBox's independent folder presentation. It receives only folder data,
/// a binding to the visible folder page and actions from the Home coordinator.
/// Launching and modifying guest apps are deliberately outside this view.
struct BloomBoxFolderPanel<Icon: View>: View {
    let folder: LiveBoardHomeLayout.Folder
    let width: CGFloat
    let reduceMotion: Bool
    @Binding var page: Int
    let icon: (String) -> Icon
    let rename: () -> Void
    let close: () -> Void

    private var pageCount: Int { max(1, (folder.apps.count + 8) / 9) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: close)

            VStack(spacing: 28) {
                Button(action: rename) {
                    Text(folder.name)
                        .font(.system(size: 30, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Renombrar carpeta " + folder.name)

                TabView(selection: $page) {
                    ForEach(0..<pageCount, id: \.self) { group in
                        VStack(spacing: 0) {
                            ForEach(0..<3, id: \.self) { row in
                                HStack(alignment: .top, spacing: 0) {
                                    ForEach(0..<3, id: \.self) { column in
                                        let position = group * 9 + row * 3 + column
                                        Group {
                                            if folder.apps.indices.contains(position) {
                                                icon(folder.apps[position])
                                            } else {
                                                Color.clear.frame(width: 60, height: 80)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 96, alignment: .top)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 28)
                        .tag(group)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: pageCount > 1 ? .always : .never))
                .frame(width: min(width - 56, 340), height: 340)
                .liveBoardGlass(radius: 38, interactive: false)
                .accessibilityIdentifier("bloombox.folder.pages")

                Button("Cerrar", action: close)
                    .font(.subheadline)
                    .accessibilityIdentifier("home.folder.close")
            }
            .offset(y: -25)
        }
        .accessibilityAddTraits(.isModal)
        .transition(reduceMotion ? .opacity :
            .asymmetric(insertion: .scale(scale: 0.58, anchor: .center).combined(with: .opacity),
                        removal: .scale(scale: 0.78, anchor: .center).combined(with: .opacity)))
    }
}
