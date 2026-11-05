// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 adri23rep-stack.
// Nikaido-inspired DualSense controls for the GameBox host only.
// No Windows HID/ViGEm code is bundled; guest input interception is not implemented.
import SwiftUI
import GameController

private enum NikaidoLightStyle: String, CaseIterable, Codable {
    case fixed, breathe, rainbow, pulse, heartbeat, wave, comet, aurora, fire, police, sparkle, sunset

    var title: String {
        switch self {
        case .fixed: return "Color fijo"
        case .breathe: return "Respiración"
        case .rainbow: return "Arcoíris"
        case .pulse: return "Pulso suave"
        case .heartbeat: return "Latido"
        case .wave: return "Ola neón"
        case .comet: return "Cometa"
        case .aurora: return "Aurora"
        case .fire: return "Fuego"
        case .police: return "Sirena"
        case .sparkle: return "Destellos"
        case .sunset: return "Atardecer"
        }
    }

    var symbol: String {
        switch self {
        case .fixed: return "paintpalette.fill"
        case .breathe: return "wind"
        case .rainbow: return "rainbow"
        case .pulse: return "circle.dotted.circle"
        case .heartbeat: return "heart.fill"
        case .wave: return "water.waves"
        case .comet: return "sparkle"
        case .aurora: return "moon.stars.fill"
        case .fire: return "flame.fill"
        case .police: return "light.beacon.max.fill"
        case .sparkle: return "sparkles"
        case .sunset: return "sun.horizon.fill"
        }
    }

    var animated: Bool { self != .fixed }
}

private enum NikaidoTriggerStyle: String, CaseIterable, Codable {
    case off, resistance, weapon, vibration, soft, heavy, sniper, bow, recoil, rapid, ramp

    var title: String {
        switch self {
        case .off: return "Apagado"
        case .resistance: return "Resistencia"
        case .weapon: return "Gatillo de arma"
        case .vibration: return "Pulso"
        case .soft: return "Suave"
        case .heavy: return "Pesado"
        case .sniper: return "Francotirador"
        case .bow: return "Arco"
        case .recoil: return "Retroceso"
        case .rapid: return "Ráfaga"
        case .ramp: return "Progresivo"
        }
    }

    var detail: String {
        switch self {
        case .off: return "Sin resistencia"
        case .resistance: return "Punto de presión configurable"
        case .weapon: return "Disparo con recorrido"
        case .vibration: return "Vibración al presionar"
        case .soft: return "Recorrido ligero"
        case .heavy: return "Presión intensa"
        case .sniper: return "Disparo de precisión"
        case .bow: return "Fuerza creciente"
        case .recoil: return "Golpe en el gatillo"
        case .rapid: return "Vibración rápida"
        case .ramp: return "Rampa de resistencia"
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
    var secondaryRed: Double = 0.98
    var secondaryGreen: Double = 0.29
    var secondaryBlue: Double = 0.65
    var lightBrightness: Double = 0.8
    var lightSpeed: Double = 1.0
    var leftTriggerStyle: NikaidoTriggerStyle = .off
    var rightTriggerStyle: NikaidoTriggerStyle = .off
    var leftStrength: Double = 0.45
    var rightStrength: Double = 0.45
    var leftStart: Double = 0.25
    var rightStart: Double = 0.25
    var leftDriftX: Double = 0
    var leftDriftY: Double = 0
    var rightDriftX: Double = 0
    var rightDriftY: Double = 0
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
              let original = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let fallbackData = try? JSONEncoder().encode(Self()),
              var merged = (try? JSONSerialization.jsonObject(with: fallbackData)) as? [String: Any] else {
            return Self()
        }
        // Merge new defaults with legacy profiles so adding a field never erases
        // previously saved RGB, triggers, stick settings, or remaps.
        merged.merge(original) { _, old in old }
        guard let compatible = try? JSONSerialization.data(withJSONObject: merged),
              let decoded = try? JSONDecoder().decode(Self.self, from: compatible) else {
            return Self()
        }
        // Clamp corrupt/stale values before they reach the physical controller.
        var safe = decoded
        safe.red = safe.red.isFinite ? min(max(safe.red, 0), 1) : 0.25
        safe.green = safe.green.isFinite ? min(max(safe.green, 0), 1) : 0.57
        safe.blue = safe.blue.isFinite ? min(max(safe.blue, 0), 1) : 1
        safe.secondaryRed = safe.secondaryRed.isFinite ? min(max(safe.secondaryRed, 0), 1) : 1
        safe.secondaryGreen = safe.secondaryGreen.isFinite ? min(max(safe.secondaryGreen, 0), 1) : 0.29
        safe.secondaryBlue = safe.secondaryBlue.isFinite ? min(max(safe.secondaryBlue, 0), 1) : 0.65
        safe.lightBrightness = safe.lightBrightness.isFinite ? min(max(safe.lightBrightness, 0), 1) : 0.8
        safe.lightSpeed = safe.lightSpeed.isFinite ? min(max(safe.lightSpeed, 0.25), 3) : 1.0
        safe.leftStart = safe.leftStart.isFinite ? min(max(safe.leftStart, 0.05), 0.65) : 0.25
        safe.rightStart = safe.rightStart.isFinite ? min(max(safe.rightStart, 0.05), 0.65) : 0.25
        safe.leftDriftX = safe.leftDriftX.isFinite ? min(max(safe.leftDriftX, -0.2), 0.2) : 0
        safe.leftDriftY = safe.leftDriftY.isFinite ? min(max(safe.leftDriftY, -0.2), 0.2) : 0
        safe.rightDriftX = safe.rightDriftX.isFinite ? min(max(safe.rightDriftX, -0.2), 0.2) : 0
        safe.rightDriftY = safe.rightDriftY.isFinite ? min(max(safe.rightDriftY, -0.2), 0.2) : 0
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

    static func shaped(x: Float, y: Float, deadzone: Double, sensitivity: Double,
                       invertY: Bool, offsetX: Double = 0, offsetY: Double = 0) -> (Float, Float) {
        let cx = max(-1, min(1, Double(x) - offsetX))
        let cy = max(-1, min(1, Double(y) - offsetY))
        let distance = min(1, hypot(cx, cy))
        let zone = min(max(deadzone, 0), 0.5)
        if distance <= zone || distance == 0 { return (0, 0) }
        let magnitude = min(1, ((distance - zone) / (1 - zone)) * min(max(sensitivity, 0.5), 2))
        let scale = Float(magnitude / distance)
        return (Float(cx) * scale, Float(cy) * scale * (invertY ? -1 : 1))
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
    @Published private(set) var calibrating = false
    @Published private(set) var calibrationProgress: Double = 0
    @Published private(set) var calibrationMessage = "Sin calibrar"

    private var gameKey = ""
    private var controller: GCController?
    private var lightTimer: Timer?
    private var appliedTriggers = false
    private var calibrationSamples: [(Double, Double, Double, Double)] = []
    private let sampleTarget = 60

    func activate(gameKey: String) {
        stopEffects()
        self.gameKey = gameKey
        profile = .load(for: gameKey)
        refresh()
    }

    func refresh() {
        let current = GCController.controllers()
        let preferred = current.first(where: { $0.extendedGamepad is GCDualSenseGamepad }) ?? current.first
        if controller !== preferred {
            stopEffects()
            if calibrating { cancelCalibration("El control se desconectó. Intenta de nuevo.") }
        }
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
        collectCalibrationSample()
    }

    func beginCalibration() {
        guard isDualSense, controller?.extendedGamepad != nil else {
            calibrationMessage = "Conecta un DualSense para calibrar."
            return
        }
        calibrationSamples.removeAll(keepingCapacity: true)
        calibrationProgress = 0
        calibrating = true
        calibrationMessage = "No toques las palancas durante 3 segundos."
    }

    func cancelCalibration(_ message: String = "Calibración cancelada.") {
        calibrating = false
        calibrationSamples.removeAll()
        calibrationProgress = 0
        calibrationMessage = message
    }

    private func collectCalibrationSample() {
        guard calibrating, controller?.extendedGamepad != nil else { return }
        let values = (Double(leftRaw.0), Double(leftRaw.1),
                      Double(rightRaw.0), Double(rightRaw.1))
        let axes = [values.0, values.1, values.2, values.3]
        guard axes.allSatisfy({ $0.isFinite && abs($0) < 0.22 }) else {
            cancelCalibration("Detecté movimiento o drift demasiado alto. Suelta las palancas e inténtalo otra vez.")
            return
        }
        calibrationSamples.append(values)
        calibrationProgress = Double(calibrationSamples.count) / Double(sampleTarget)
        guard calibrationSamples.count >= sampleTarget else { return }
        let count = Double(calibrationSamples.count)
        let means = (calibrationSamples.reduce(0) { $0 + $1.0 } / count,
                     calibrationSamples.reduce(0) { $0 + $1.1 } / count,
                     calibrationSamples.reduce(0) { $0 + $1.2 } / count,
                     calibrationSamples.reduce(0) { $0 + $1.3 } / count)
        let deviation = calibrationSamples.map { sample in
            max(abs(sample.0 - means.0), abs(sample.1 - means.1),
                abs(sample.2 - means.2), abs(sample.3 - means.3))
        }.max() ?? 0
        guard deviation <= 0.07 else {
            cancelCalibration("Las lecturas no fueron estables. No se guardó ningún cambio.")
            return
        }
        // Calibrates software center offsets for GameBox's preview/compatible
        // guest bridges; it cannot modify controller firmware or heal damage.
        let recommended = min(0.25, max(0.035, deviation * 3 + 0.02))
        change { p in
            p.leftDriftX = means.0
            p.leftDriftY = means.1
            p.rightDriftX = means.2
            p.rightDriftY = means.3
            p.leftDeadzone = max(p.leftDeadzone, recommended)
            p.rightDeadzone = max(p.rightDeadzone, recommended)
        }
        calibrating = false
        calibrationSamples.removeAll()
        calibrationProgress = 1
        calibrationMessage = String(format: "Centro guardado · variación máxima %.3f", deviation)
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
        applyTrigger(profile.leftTriggerStyle, strength: profile.leftStrength,
                     start: profile.leftStart, left: true)
        applyTrigger(profile.rightTriggerStyle, strength: profile.rightStrength,
                     start: profile.rightStart, left: false)
        if supportsLight {
            updateLight()
            if profile.lightStyle.animated {
                lightTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.updateLight() }
                }
            }
        }
    }

    private func applyTrigger(_ effect: NikaidoTriggerStyle, strength: Double,
                              start: Double, left: Bool) {
        guard let pad = controller?.extendedGamepad as? GCDualSenseGamepad else { return }
        let trigger = left ? pad.leftTrigger : pad.rightTrigger
        let force = Float(min(max(strength, 0), 1))
        let startPosition = Float(min(max(start, 0.05), 0.65))
        guard force > 0, effect != .off else {
            trigger.setModeOff()
            return
        }
        appliedTriggers = true
        switch effect {
        case .off: trigger.setModeOff()
        case .resistance:
            trigger.setModeFeedbackWithStartPosition(startPosition, resistiveStrength: force)
        case .soft:
            trigger.setModeFeedbackWithStartPosition(startPosition, resistiveStrength: force * 0.35)
        case .heavy:
            trigger.setModeFeedbackWithStartPosition(startPosition, resistiveStrength: min(1, force * 1.25))
        case .weapon:
            trigger.setModeWeaponWithStartPosition(startPosition, endPosition: 0.84, resistiveStrength: force)
        case .sniper:
            trigger.setModeWeaponWithStartPosition(0.58, endPosition: 0.92, resistiveStrength: force)
        case .bow:
            trigger.setModeSlopeFeedback(startPosition: startPosition, endPosition: 0.96,
                                         startStrength: force * 0.2, endStrength: force)
        case .ramp:
            trigger.setModeSlopeFeedback(startPosition: startPosition, endPosition: 0.9,
                                         startStrength: 0, endStrength: force)
        case .vibration:
            trigger.setModeVibrationWithStartPosition(startPosition, amplitude: force, frequency: 0.22)
        case .recoil:
            trigger.setModeVibrationWithStartPosition(startPosition, amplitude: force, frequency: 0.62)
        case .rapid:
            trigger.setModeVibrationWithStartPosition(startPosition, amplitude: force, frequency: 0.88)
        }
    }

    private func updateLight() {
        guard let light = controller?.light else { return }
        let t = Date().timeIntervalSinceReferenceDate * profile.lightSpeed
        let primary = [profile.red, profile.green, profile.blue]
        let secondary = [profile.secondaryRed, profile.secondaryGreen, profile.secondaryBlue]
        func mix(_ a: [Double], _ b: [Double], _ f: Double) -> [Double] {
            let amount = min(1, max(0, f))
            return zip(a, b).map { $0 * (1 - amount) + $1 * amount }
        }
        func rainbow(_ hue: Double) -> [Double] {
            let color = UIColor(hue: CGFloat(hue - floor(hue)), saturation: 0.95,
                                brightness: 1, alpha: 1)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return [Double(r), Double(g), Double(b)]
        }
        var rgb = primary
        var brightness = profile.lightBrightness
        let wave = 0.5 + 0.5 * sin(t * 2.2)
        switch profile.lightStyle {
        case .fixed: break
        case .breathe:
            brightness *= 0.15 + 0.85 * wave
        case .rainbow:
            rgb = rainbow(t / 9)
        case .pulse:
            brightness *= 0.18 + 0.82 * pow(wave, 4)
        case .heartbeat:
            let beat = t.truncatingRemainder(dividingBy: 2)
            brightness *= 0.12 + 0.88 * max(exp(-pow((beat - 0.18) * 7, 2)),
                                            0.58 * exp(-pow((beat - 0.54) * 7, 2)))
        case .wave:
            rgb = mix(primary, secondary, wave)
        case .comet:
            let phase = t.truncatingRemainder(dividingBy: 2.8) / 2.8
            brightness *= 0.1 + 0.9 * exp(-phase * 5)
            rgb = mix(primary, secondary, phase)
        case .aurora:
            rgb = mix(rainbow(0.45 + sin(t / 4) * 0.09),
                      rainbow(0.79 + sin(t / 7) * 0.09), wave)
        case .fire:
            rgb = mix([1, 0.08, 0], [1, 0.57, 0.02], wave)
            brightness *= 0.62 + 0.3 * (0.5 + 0.5 * sin(t * 8))
        case .police:
            rgb = sin(t * 3.2) >= 0 ? [1, 0.02, 0.04] : [0.01, 0.1, 1]
        case .sparkle:
            rgb = mix(primary, [1, 1, 1], pow(max(0, sin(t * 5)), 12))
        case .sunset:
            rgb = mix([1, 0.26, 0.04], [0.54, 0.08, 0.65], wave)
        }
        light.color = GCColor(red: Float(min(1, max(0, rgb[0] * brightness))),
                              green: Float(min(1, max(0, rgb[1] * brightness))),
                              blue: Float(min(1, max(0, rgb[2] * brightness))))
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
        cancelCalibration()
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

                Section {
                    lightPreview
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                        GridItem(.flexible())], spacing: 8) {
                        ForEach(NikaidoLightStyle.allCases, id: \.self) { item in
                            lightCell(item)
                        }
                    }
                    .padding(.vertical, 6)
                    HStack {
                        ColorPicker("Principal", selection: colorBinding(primary: true), supportsOpacity: false)
                        ColorPicker("Secundario", selection: colorBinding(primary: false), supportsOpacity: false)
                    }
                    HStack {
                        Text("Brillo")
                        Slider(value: binding(\.lightBrightness), in: 0...1)
                        Text("\(Int(host.profile.lightBrightness * 100))%")
                            .monospacedDigit().frame(width: 46)
                    }
                    HStack {
                        Text("Velocidad")
                        Slider(value: binding(\.lightSpeed), in: 0.25...3)
                        Text(String(format: "%.1fx", host.profile.lightSpeed))
                            .monospacedDigit().frame(width: 46)
                    }.disabled(!host.profile.lightStyle.animated)
                } header: {
                    Label("RGB Studio · 12 efectos", systemImage: "lightspectrum.horizontal")
                } footer: {
                    Text("El DualSense tiene una barra de un solo color. GameBox anima el color, no zonas LED independientes. El juego puede reemplazar el efecto.")
                }
                .disabled(!host.supportsLight)

                Section("Gatillos adaptativos") {
                    triggerRow("L2", style: \.leftTriggerStyle, strength: \.leftStrength,
                               start: \.leftStart)
                    triggerRow("R2", style: \.rightTriggerStyle, strength: \.rightStrength,
                               start: \.rightStart)
                    HStack {
                        Button("Copiar L2 → R2") {
                            host.change { p in
                                p.rightTriggerStyle = p.leftTriggerStyle
                                p.rightStrength = p.leftStrength
                                p.rightStart = p.leftStart
                            }
                        }
                        Spacer()
                        Button("Apagar ambos") {
                            host.change { p in
                                p.leftTriggerStyle = .off
                                p.rightTriggerStyle = .off
                            }
                        }
                    }.font(.subheadline).disabled(!host.isDualSense)
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Autocalibración de drift", systemImage: "scope").font(.headline)
                        Text("Apoya el control, suelta las dos palancas y no las toques durante la medición.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if host.calibrating {
                            ProgressView(value: host.calibrationProgress)
                            Button("Cancelar medición") { host.cancelCalibration() }
                        } else {
                            Button { host.beginCalibration() } label: {
                                Label("Medir y calibrar centro", systemImage: "dot.scope")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent).disabled(!host.isDualSense)
                        }
                        Text(host.calibrationMessage).font(.caption).foregroundStyle(.secondary)
                        if !host.calibrating {
                            Button("Borrar compensación de drift") {
                                host.change { p in
                                    p.leftDriftX = 0; p.leftDriftY = 0
                                    p.rightDriftX = 0; p.rightDriftY = 0
                                }
                            }.font(.caption)
                        }
                    }
                    stickRow("Palanca izquierda", deadzone: \.leftDeadzone,
                             sensitivity: \.leftSensitivity, invert: \.invertLeftY,
                             offsetX: \.leftDriftX, offsetY: \.leftDriftY,
                             physical: host.leftRaw)
                    stickRow("Palanca derecha", deadzone: \.rightDeadzone,
                             sensitivity: \.rightSensitivity, invert: \.invertRightY,
                             offsetX: \.rightDriftX, offsetY: \.rightDriftY,
                             physical: host.rightRaw)
                } header: {
                    Text("Input Studio · vista previa")
                } footer: {
                    Text("La medición guarda compensaciones del centro y ajusta la zona muerta si hace falta. NO repara el hardware ni cambia controles en apps invitadas hasta integrar su puente de entradas.")
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
            .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
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
                .foregroundStyle(available ? Color.green : Color.secondary)
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
