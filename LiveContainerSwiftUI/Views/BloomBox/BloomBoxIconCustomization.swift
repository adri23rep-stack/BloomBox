import SwiftUI

/// BloomBox icon appearance. Old preference keys are retained so existing
/// themes and per-device choices render identically after the UI rewrite.
struct BloomBoxIconTreatment: ViewModifier {
    @AppStorage("ManzanaIconStyle", store: LCUtils.appGroupUserDefault)
    private var style = "default"
    @AppStorage("ManzanaIconMode", store: LCUtils.appGroupUserDefault)
    private var mode = "auto"
    @AppStorage("ManzanaIconHue", store: LCUtils.appGroupUserDefault)
    private var hue = 0.58
    @AppStorage("ManzanaIconIntensity", store: LCUtils.appGroupUserDefault)
    private var intensity = 0.65
    @Environment(\.colorScheme) private var colorScheme

    private var dark: Bool {
        mode == "dark" || (mode == "auto" && colorScheme == .dark)
    }

    func body(content: Content) -> some View {
        content
            .saturation(style == "clear" || style == "tinted" ? 0 : 1)
            .brightness(style == "dark" ? -0.12 : 0)
            .opacity(style == "clear" ? (dark ? 0.64 : 0.82) : 1)
            .overlay {
                if style == "tinted" {
                    Color(hue: hue, saturation: 0.8,
                          brightness: dark ? 0.65 : 1)
                        .opacity(intensity)
                        .blendMode(.color)
                        .allowsHitTesting(false)
                }
            }
            .background {
                if style == "clear" {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                }
            }
            .compositingGroup()
    }
}

struct BloomBoxIconCustomization: View {
    @AppStorage("ManzanaIconStyle", store: LCUtils.appGroupUserDefault)
    private var style = "default"
    @AppStorage("ManzanaIconMode", store: LCUtils.appGroupUserDefault)
    private var mode = "auto"
    @AppStorage("ManzanaIconHue", store: LCUtils.appGroupUserDefault)
    private var hue = 0.58
    @AppStorage("ManzanaIconIntensity", store: LCUtils.appGroupUserDefault)
    private var intensity = 0.65
    @AppStorage("LiveBoardLargeIcons", store: LCUtils.appGroupUserDefault)
    private var large = false

    private let choices = ["default", "dark", "clear", "tinted"]

    private func title(for value: String) -> String {
        switch value {
        case "dark": return "Oscuro"
        case "clear": return "Cristal"
        case "tinted": return "Teñido"
        default: return "Original"
        }
    }

    private func symbolColor(for value: String) -> Color {
        value == "tinted"
            ? Color(hue: hue, saturation: 0.7, brightness: 1)
            : .white
    }

    private func preview(for value: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(value == "default" ? Color.blue :
                      Color.black.opacity(value == "dark" ? 0.85 : 0.35))
            if value == "clear" {
                RoundedRectangle(cornerRadius: 15)
                    .fill(.ultraThinMaterial)
            }
            Image(systemName: "cloud.sun.fill")
                .symbolRenderingMode(
                    value == "default" || value == "dark"
                        ? .multicolor : .monochrome
                )
                .foregroundStyle(symbolColor(for: value))
                .font(.system(size: 28))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .accessibilityHidden(true)
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "paintpalette.fill")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Personalizar iconos")
                    .font(.headline)
                Spacer()
                Button { large.toggle() } label: {
                    Image(systemName: large ? "square.fill" : "square.grid.2x2")
                }
                .accessibilityLabel(
                    large ? "Usar iconos pequeños" : "Usar iconos grandes"
                )
            }
            HStack(spacing: 10) {
                ForEach(choices, id: \.self) { value in
                    Button { style = value } label: {
                        VStack(spacing: 8) {
                            preview(for: value)
                            Text(title(for: value))
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .background(
                                    style == value
                                        ? Color.primary.opacity(0.15) : .clear,
                                    in: Capsule()
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(
                        style == value ? .isSelected : []
                    )
                }
            }
            if style == "clear" || style == "tinted" {
                Picker("Apariencia", selection: $mode) {
                    Text("Claro").tag("light")
                    Text("Oscuro").tag("dark")
                    Text("Auto").tag("auto")
                }
                .pickerStyle(.segmented)
            }
            if style == "tinted" {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Color")
                        Spacer()
                        Circle()
                            .fill(Color(hue: hue, saturation: 0.8, brightness: 1))
                            .frame(width: 16, height: 16)
                            .accessibilityHidden(true)
                    }
                    .font(.caption)
                    Slider(value: $hue, in: 0...1)
                        .tint(Color(hue: hue, saturation: 0.8, brightness: 1))
                    Text("Intensidad").font(.caption)
                    Slider(value: $intensity, in: 0...1)
                }
            }
        }
        .padding(20)
        .liveBoardGlass(radius: 32)
    }
}
