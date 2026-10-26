import SwiftUI

/// Presentation only: original app assets remain untouched.
struct ManzanaIconTreatment: ViewModifier {
    @AppStorage("ManzanaIconStyle", store: LCUtils.appGroupUserDefault) private var style = "default"
    @AppStorage("ManzanaIconMode", store: LCUtils.appGroupUserDefault) private var mode = "auto"
    @AppStorage("ManzanaIconHue", store: LCUtils.appGroupUserDefault) private var hue = 0.58
    @AppStorage("ManzanaIconIntensity", store: LCUtils.appGroupUserDefault) private var intensity = 0.65
    @Environment(\.colorScheme) private var scheme
    private var dark: Bool { mode == "dark" || (mode == "auto" && scheme == .dark) }
    func body(content: Content) -> some View {
        content
            .saturation(style == "clear" || style == "tinted" ? 0 : 1)
            .brightness(style == "dark" ? -0.12 : 0)
            .opacity(style == "clear" ? (dark ? 0.64 : 0.82) : 1)
            .overlay {
                if style == "tinted" {
                    Color(hue: hue, saturation: 0.8, brightness: dark ? 0.65 : 1)
                        .opacity(intensity).blendMode(.color).allowsHitTesting(false)
                }
            }
            .background {
                if style == "clear" {
                    RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial)
                }
            }
            .compositingGroup()
    }
}

struct ManzanaIconCustomization: View {
    @AppStorage("ManzanaIconStyle", store: LCUtils.appGroupUserDefault) private var style = "default"
    @AppStorage("ManzanaIconMode", store: LCUtils.appGroupUserDefault) private var mode = "auto"
    @AppStorage("ManzanaIconHue", store: LCUtils.appGroupUserDefault) private var hue = 0.58
    @AppStorage("ManzanaIconIntensity", store: LCUtils.appGroupUserDefault) private var intensity = 0.65
    @AppStorage("LiveBoardLargeIcons", store: LCUtils.appGroupUserDefault) private var large = false
    private let styles = ["default", "dark", "clear", "tinted"]
    private let titles = ["Original", "Oscuro", "Cristal", "Teñido"]
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Image(systemName: "sun.max")
                Spacer()
                Text("Personalizar").font(.headline)
                Spacer()
                Button { large.toggle() } label: { Image(systemName: large ? "square.fill" : "square.grid.2x2") }
                    .accessibilityLabel(large ? "Usar iconos pequeños" : "Usar iconos grandes")
            }
            HStack(spacing: 10) {
                ForEach(Array(styles.enumerated()), id: \.element) { index, value in
                    Button { style = value } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "cloud.sun.fill")
                                .symbolRenderingMode(value == "default" || value == "dark" ? .multicolor : .monochrome)
                                .font(.system(size: 29))
                                .foregroundStyle(value == "tinted" ? Color(hue: hue, saturation: 0.7, brightness: 1) : .white)
                                .frame(maxWidth: .infinity).frame(height: 62)
                                .background(value == "default" ? Color.blue : Color.black.opacity(value == "dark" ? 0.85 : 0.35), in: RoundedRectangle(cornerRadius: 15))
                            Text(titles[index]).font(.caption.weight(.semibold)).minimumScaleFactor(0.7).lineLimit(1)
                                .padding(.horizontal, 5).padding(.vertical, 8)
                                .background(style == value ? Color.primary.opacity(0.15) : .clear, in: Capsule())
                        }
                    }.buttonStyle(.plain).accessibilityAddTraits(style == value ? .isSelected : [])
                }
            }
            if style == "clear" || style == "tinted" {
                Picker("Apariencia", selection: $mode) {
                    Text("Claro").tag("light"); Text("Oscuro").tag("dark"); Text("Auto").tag("auto")
                }.pickerStyle(.segmented)
            }
            if style == "tinted" {
                VStack(alignment: .leading) {
                    Text("Color").font(.caption)
                    Slider(value: $hue, in: 0...1).tint(Color(hue: hue, saturation: 0.8, brightness: 1))
                    Text("Intensidad").font(.caption)
                    Slider(value: $intensity, in: 0...1)
                }
            }
        }.padding(20).liveBoardGlass(radius: 32)
    }
}
