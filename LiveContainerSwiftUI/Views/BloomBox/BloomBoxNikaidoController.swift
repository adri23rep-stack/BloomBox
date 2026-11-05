// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 adri23rep-stack.
// Nikaido-inspired DualSense controls for the GameBox host only.
// No Windows HID/ViGEm code is bundled; guest input interception is not implemented.
import SwiftUI
import GameController

private enum NikaidoLightStyle: String, CaseIterable, Codable {
    case fixed, breathe, rainbow

    var title: String {
        switch self {
        case .fixed: return "Fijo"
        case .breathe: return "Respiración"
        case .rainbow: return "Arcoíris"
        }
    }
}

private enum NikaidoTriggerStyle: String, CaseIterable, Codable {
    case off, resistance, weapon, vibration

    var title: String {
        switch self {
        case .off: return "Desactivado"
        case .resistance: return "Resistencia"
        case .weapon: return "Arma"
        case .vibration: return "Pulso"
        }
    }
}

/// The native GameController API applies effects while the host is active.
/// Input shaping and remaps are persisted for future guest-specific bridges;
/// these preferences must never be advertised as system-wide remapping.
private struct NikaidoGameProfile: Codable, Equatable {
    var red: Double = 0.25
    var green: Double = 0.57
    var blue: Double = 1.0
    var lightStyle: NikaidoLightStyle = .fixed
    var leftTriggerStyle: NikaidoTriggerStyle = .off
    var rightTriggerStyle: NikaidoTriggerStyle = .off
    var leftStrength: Double = 0.45
    var rightStrength: Double = 0.45
    var leftDeadzone: Double = 0.08
    var rightDeadzone: Double = 0.08
    var leftSensitivity: Double = 1.0
    var rightSensitivity: Double = 1.0
    var invertLeftY: Bool = false
    var invertRightY: Bool = false
    var crossMapping: String = "A"
    var circleMapping: String = "B"

    static func load(for key: String) -> NikaidoGameProfile {
        guard let data = LiveContainerPreferencesAdapter.defaults.data(forKey: "BloomBoxNikaido:" + key),
              data.count < 16_384,
              let decoded = try? JSONDecoder().decode(Self.self, from: data) else {
            return Self()
        }
        // Clamp corrupt/stale values before they reach the physical controller.
        var safe = decoded
        safe.red = safe.red.isFinite ? min(max(safe.red, 0), 1) : 0.25
        safe.green = safe.green.isFinite ? min(max(safe.green, 0), 1) : 0.57
        safe.blue = safe.blue.isFinite ? min(max(safe.blue, 0), 1) : 1
        safe.leftStrength = safe.leftStrength.isFinite ? min(max(safe.leftStrength, 0), 1) : 0
        safe.rightStrength = safe.rightStrength.isFinite ? min(max(safe.rightStrength, 0), 1) : 0
        safe.leftDeadzone = safe.leftDeadzone.isFinite ? min(max(safe.leftDeadzone, 0), 0.5) : 0.08
        safe.rightDeadzone = safe.rightDeadzone.isFinite ? min(max(safe.rightDeadzone, 0), 0.5) : 0.08
        safe.leftSensitivity = safe.leftSensitivity.isFinite ? min(max(safe.leftSensitivity, 0.5), 2) : 1
        safe.rightSensitivity = safe.rightSensitivity.isFinite ? min(max(safe.rightSensitivity, 0.5), 2) : 1
        if !["A", "B", "X", "Y", "none"].contains(safe.crossMapping) { safe.crossMapping = "A" }
        if !["A", "B", "X", "Y", "none"].contains(safe.circleMapping) { safe.circleMapping = "B" }
        return safe
    }

    func save(for key: String) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        LiveContainerPreferencesAdapter.defaults.set(data, forKey: "BloomBoxNikaido:" + key)
    }

    static func shaped(x: Float, y: Float, deadzone: Double, sensitivity: Double, invertY: Bool) -> (Float, Float) {
        let distance = min(1, hypot(Double(x), Double(y)))
        let zone = min(max(deadzone, 0), 0.5)
        if distance <= zone || distance == 0 { return (0, 0) }
        let magnitude = min(1, ((distance - zone) / (1 - zone)) * min(max(sensitivity, 0.5), 2))
        let scale = Float(magnitude / distance)
        return (x * scale, y * scale * (invertY ? -1 : 1))
    }
}

@MainActor
private final class NikaidoGameControllerHost: ObservableObject {
    @Published var profile = NikaidoGameProfile()
    @Published private(set) var controllerName = "Sin control conectado"
    @Published private(set) var isDualSense = false
    @Published private(set) var supportsLight = false
    @Published private(set) var supportsHaptics = false
    @Published private(set) var batteryText = "No disponible"
    @Published private(set) var leftRaw: (Float, Float) = (0, 0)
    @Published private(set) var rightRaw: (Float, Float) = (0, 0)

    private var gameKey = ""
    private var controller: GCController?
    private var lightTimer: Timer?
    private var appliedTriggers = false

    func activate(gameKey: String) {
        stopEffects()
        self.gameKey = gameKey
        profile = .load(for: gameKey)
        refresh()
    }

    func refresh() {
        let current = GCController.controllers()
        let preferred = current.first(where: { $0.extendedGamepad is GCDualSenseGamepad }) ?? current.first
        if controller !== preferred { stopEffects() }
        controller = preferred
        controllerName = preferred?.vendorName ?? "Sin control conectado"
        isDualSense = preferred?.extendedGamepad is GCDualSenseGamepad
        supportsLight = preferred?.light != nil
        supportsHaptics = preferred?.haptics != nil
        if let battery = preferred?.battery {
            let value = Int((battery.batteryLevel * 100).rounded())
            batteryText = (0...100).contains(value) ? "\(value)%" : "No disponible"
        } else {
            batteryText = "No disponible"
        }
        applyEffects()
    }

    func sampleInput() {
        guard let pad = controller?.extendedGamepad else {
            leftRaw = (0, 0)
            rightRaw = (0, 0)
            return
        }
        leftRaw = (pad.leftThumbstick.xAxis.value, pad.leftThumbstick.yAxis.value)
        rightRaw = (pad.rightThumbstick.xAxis.value, pad.rightThumbstick.yAxis.value)
    }

    func change(_ change: (inout NikaidoGameProfile) -> Void) {
        change(&profile)
        profile.save(for: gameKey)
        applyEffects()
    }

    private func applyEffects() {
        lightTimer?.invalidate()
        lightTimer = nil
        guard controller != nil else { return }
        applyTrigger(profile.leftTriggerStyle, strength: profile.leftStrength, left: true)
        applyTrigger(profile.rightTriggerStyle, strength: profile.rightStrength, left: false)
        if supportsLight {
            updateLight()
            if profile.lightStyle != .fixed {
                lightTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.updateLight() }
                }
            }
        }
    }

    private func applyTrigger(_ effect: NikaidoTriggerStyle, strength: Double, left: Bool) {
        guard let pad = controller?.extendedGamepad as? GCDualSenseGamepad else { return }
        let trigger = left ? pad.leftTrigger : pad.rightTrigger
        let force = Float(min(max(strength, 0), 1))
        guard force > 0, effect != .off else {
            trigger.setModeOff()
            return
        }
        appliedTriggers = true
        switch effect {
        case .off: trigger.setModeOff()
        case .resistance:
            trigger.setModeFeedbackWithStartPosition(0.25, resistiveStrength: force)
        case .weapon:
            trigger.setModeWeaponWithStartPosition(0.2, endPosition: 0.8, resistiveStrength: force)
        case .vibration:
            trigger.setModeVibrationWithStartPosition(0.25, amplitude: force, frequency: 12)
        }
    }

    private func updateLight() {
        guard let light = controller?.light else { return }
        var red = profile.red
        var green = profile.green
        var blue = profile.blue
        switch profile.lightStyle {
        case .fixed: break
        case .breathe:
            let factor = 0.25 + 0.75 * (0.5 + 0.5 * sin(Date().timeIntervalSinceReferenceDate * 2))
            red *= factor
            green *= factor
            blue *= factor
        case .rainbow:
            let hue = Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 8) / 8
            let rgb = UIColor(hue: CGFloat(hue), saturation: 0.9, brightness: 1, alpha: 1)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
            red = Double(r)
            green = Double(g)
            blue = Double(b)
        }
        light.color = GCColor(red: Float(red), green: Float(green), blue: Float(blue))
    }

    func stopEffects() {
        lightTimer?.invalidate()
        lightTimer = nil
        if appliedTriggers, let pad = controller?.extendedGamepad as? GCDualSenseGamepad {
            pad.leftTrigger.setModeOff()
            pad.rightTrigger.setModeOff()
        }
        appliedTriggers = false
    }

    func deactivate() {
        stopEffects()
        controller = nil
    }
}

@available(iOS 16.0, *)
struct BloomBoxNikaidoControllerView: View {
    let gameID: String
    let gameName: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var host = NikaidoGameControllerHost()

    private var connected: Bool { host.isDualSense || host.supportsLight || host.batteryText != "No disponible" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(host.controllerName, systemImage: host.isDualSense ? "gamecontroller.fill" : "gamecontroller")
                    HStack {
                        Label("Batería del control", systemImage: "battery.75")
                        Spacer()
                        Text(host.batteryText).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 14) {
                        availability("RGB", host.supportsLight)
                        availability("Gatillos", host.isDualSense)
                        availability("Vibración", host.supportsHaptics)
                    }
                    Button("Buscar controles conectados") { host.refresh() }
                } header: {
                    Text(gameName)
                } footer: {
                    Text("Los efectos se prueban desde GameBox; un emulador puede sobrescribirlos al abrirse.")
                }

                Section("Luces RGB") {
                    Picker("Efecto", selection: binding(\.lightStyle)) {
                        ForEach(NikaidoLightStyle.allCases, id: \.self) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .disabled(!host.supportsLight)
                    ColorPicker("Color principal", selection: Binding(
                        get: { Color(red: host.profile.red, green: host.profile.green, blue: host.profile.blue) },
                        set: { color in
                            let ui = UIColor(color)
                            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                            guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return }
                            host.change { $0.red = Double(r); $0.green = Double(g); $0.blue = Double(b) }
                        }
                    ), supportsOpacity: false)
                    .disabled(!host.supportsLight || host.profile.lightStyle == .rainbow)
                }

                Section("Gatillos adaptativos") {
                    triggerRow("L2", style: \.leftTriggerStyle, strength: \.leftStrength)
                    triggerRow("R2", style: \.rightTriggerStyle, strength: \.rightStrength)
                }

                Section {
                    stickRow("Palanca izquierda", deadzone: \.leftDeadzone,
                             sensitivity: \.leftSensitivity, invert: \.invertLeftY,
                             physical: host.leftRaw)
                    stickRow("Palanca derecha", deadzone: \.rightDeadzone,
                             sensitivity: \.rightSensitivity, invert: \.invertRightY,
                             physical: host.rightRaw)
                } header: {
                    Text("Input Studio · vista previa")
                } footer: {
                    Text("Aquí se calcula y guarda el ajuste. Aún NO modifica las entradas de los juegos: para eso se necesita un puente específico en el emulador.")
                }

                Section {
                    mappingRow("Cruz (×)", key: \.crossMapping)
                    mappingRow("Círculo (○)", key: \.circleMapping)
                } header: {
                    Text("Remapeo · perfil preparado")
                } footer: {
                    Text("El remapeo se guarda por juego, pero todavía NO altera botones dentro de las apps invitadas. No se inyectan entradas ni se realizan cambios globales en iOS.")
                }

                Section {
                    Menu("Aplicar configuración rápida") {
                        Button("Predeterminado") { host.change { $0 = NikaidoGameProfile() } }
                        Button("Shooter") { host.change { p in
                            p.leftDeadzone = 0.04
                            p.rightDeadzone = 0.04
                            p.rightSensitivity = 1.3
                            p.rightTriggerStyle = .weapon
                            p.rightStrength = 0.55
                        } }
                        Button("Carreras") { host.change { p in
                            p.leftDeadzone = 0.12
                            p.rightDeadzone = 0.12
                            p.leftTriggerStyle = .resistance
                            p.rightTriggerStyle = .resistance
                            p.leftStrength = 0.35
                            p.rightStrength = 0.35
                        } }
                    }
                    Button("Restaurar perfil de este juego", role: .destructive) {
                        host.change { $0 = NikaidoGameProfile() }
                    }
                } header: {
                    Text("Perfiles automáticos")
                } footer: {
                    Text("Cada juego guarda su perfil de GameBox por separado. No altera perfiles de Nikaido para Windows.")
                }
            }
            .navigationTitle("Nikaido · GameBox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .onAppear { host.activate(gameKey: gameID) }
            .onDisappear { host.deactivate() }
            .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect)) { _ in host.refresh() }
            .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)) { _ in host.refresh() }
            .onReceive(Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()) { _ in
                host.sampleInput()
            }
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<NikaidoGameProfile, T>) -> Binding<T> {
        Binding(
            get: { host.profile[keyPath: keyPath] },
            set: { value in host.change { $0[keyPath: keyPath] = value } }
        )
    }

    private func availability(_ title: String, _ available: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: available ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(available ? .green : .secondary)
            Text(title).font(.caption)
        }
    }

    @ViewBuilder
    private func triggerRow(
        _ title: String, style: WritableKeyPath<NikaidoGameProfile, NikaidoTriggerStyle>,
        strength: WritableKeyPath<NikaidoGameProfile, Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(title, selection: binding(style)) {
                ForEach(NikaidoTriggerStyle.allCases, id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }
            HStack {
                Text("Fuerza")
                Slider(value: binding(strength), in: 0...1)
                Text("\(Int(host.profile[keyPath: strength] * 100))%")
                    .monospacedDigit().frame(width: 46)
            }.font(.subheadline)
            .disabled(!host.isDualSense || host.profile[keyPath: style] == .off)
        }
        .disabled(!host.isDualSense)
    }

    @ViewBuilder
    private func stickRow(
        _ title: String,
        deadzone: WritableKeyPath<NikaidoGameProfile, Double>,
        sensitivity: WritableKeyPath<NikaidoGameProfile, Double>,
        invert: WritableKeyPath<NikaidoGameProfile, Bool>,
        physical: (Float, Float)
    ) -> some View {
        let output = NikaidoGameProfile.shaped(
            x: physical.0, y: physical.1, deadzone: host.profile[keyPath: deadzone],
            sensitivity: host.profile[keyPath: sensitivity], invertY: host.profile[keyPath: invert]
        )
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline)
            HStack {
                Text("Zona muerta")
                Slider(value: binding(deadzone), in: 0...0.5)
                Text("\(Int(host.profile[keyPath: deadzone] * 100))%")
                    .monospacedDigit().frame(width: 45)
            }
            HStack {
                Text("Sensibilidad")
                Slider(value: binding(sensitivity), in: 0.5...2)
                Text(String(format: "%.1fx", host.profile[keyPath: sensitivity]))
                    .monospacedDigit().frame(width: 45)
            }
            Toggle("Invertir eje vertical", isOn: binding(invert))
            Text(String(format: "Lectura: %.2f, %.2f · Resultado: %.2f, %.2f",
                        physical.0, physical.1, output.0, output.1))
                .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
        }.font(.subheadline)
    }

    private func mappingRow(_ name: String, key: WritableKeyPath<NikaidoGameProfile, String>) -> some View {
        Picker(name, selection: binding(key)) {
            Text("A / Cruz").tag("A")
            Text("B / Círculo").tag("B")
            Text("X / Cuadrado").tag("X")
            Text("Y / Triángulo").tag("Y")
            Text("Desactivado").tag("none")
        }
    }
}
