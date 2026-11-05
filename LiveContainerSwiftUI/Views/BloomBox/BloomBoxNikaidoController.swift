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

    var symbol: String {
        switch self {
        case .off: return "power"
        case .resistance: return "hand.raised.fill"
        case .weapon: return "scope"
        case .vibration: return "waveform"
        case .soft: return "feather.fill"
        case .heavy: return "dumbbell.fill"
        case .sniper: return "target"
        case .bow: return "arrow.up.right"
        case .recoil: return "bolt.fill"
        case .rapid: return "waveform.path"
        case .ramp: return "chart.line.uptrend.xyaxis"
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
    @Published private(set) var previewLightColor: Color = .cyan
    @Published private(set) var batteryText = "No disponible"
    @Published private(set) var leftRaw: (Float, Float) = (0, 0)
    @Published private(set) var rightRaw: (Float, Float) = (0, 0)
    @Published private(set) var leftTriggerRaw: Float = 0
    @Published private(set) var rightTriggerRaw: Float = 0
    @Published private(set) var calibrating = false
    @Published private(set) var calibrationProgress: Double = 0
    @Published private(set) var calibrationMessage = "Sin calibrar"

    private var gameKey = ""
    private var controller: GCController?
    private var lightTimer: Timer?
    private var appliedTriggers = false
    private var calibrationSamples: [(Double, Double, Double, Double)] = []
    private let sampleTarget = 60
    private var lastInputSampleUptime: TimeInterval = 0

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
        if let battery = preferred?.battery, battery.batteryLevel.isFinite,
           battery.batteryLevel >= 0, battery.batteryLevel <= 1 {
            let value = Int((battery.batteryLevel * 100).rounded())
            batteryText = "\(value)%"
        } else {
            batteryText = "No disponible"
        }
        applyEffects()
    }

    func sampleInput() {
        let now = ProcessInfo.processInfo.systemUptime
        // High frequency only during the 3-second calibration; avoid driving
        // continuous SwiftUI Form updates when the user is merely browsing.
        if !calibrating && now - lastInputSampleUptime < 0.2 { return }
        lastInputSampleUptime = now
        guard let pad = controller?.extendedGamepad else {
            leftRaw = (0, 0)
            rightRaw = (0, 0)
            leftTriggerRaw = 0
            rightTriggerRaw = 0
            return
        }
        leftRaw = (pad.leftThumbstick.xAxis.value, pad.leftThumbstick.yAxis.value)
        rightRaw = (pad.rightThumbstick.xAxis.value, pad.rightThumbstick.yAxis.value)
        leftTriggerRaw = pad.leftTrigger.value
        rightTriggerRaw = pad.rightTrigger.value
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
        applyTrigger(profile.leftTriggerStyle, strength: profile.leftStrength,
                     start: profile.leftStart, left: true)
        applyTrigger(profile.rightTriggerStyle, strength: profile.rightStrength,
                     start: profile.rightStart, left: false)
        updateLight()
        // Preview continues while disconnected. Hardware updates remain gated
        // by controller.light; no simulated device is reported as connected.
        if profile.lightStyle.animated {
            lightTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.updateLight() }
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
            if #available(iOS 15.4, *) {
                trigger.setModeSlopeFeedback(startPosition: startPosition, endPosition: 0.96,
                                             startStrength: force * 0.2, endStrength: force)
            } else {
                trigger.setModeFeedbackWithStartPosition(startPosition, resistiveStrength: force)
            }
        case .ramp:
            if #available(iOS 15.4, *) {
                trigger.setModeSlopeFeedback(startPosition: startPosition, endPosition: 0.9,
                                             startStrength: 0, endStrength: force)
            } else {
                trigger.setModeFeedbackWithStartPosition(startPosition, resistiveStrength: force)
            }
        case .vibration:
            trigger.setModeVibrationWithStartPosition(startPosition, amplitude: force, frequency: 0.22)
        case .recoil:
            trigger.setModeVibrationWithStartPosition(startPosition, amplitude: force, frequency: 0.62)
        case .rapid:
            trigger.setModeVibrationWithStartPosition(startPosition, amplitude: force, frequency: 0.88)
        }
    }

    private func updateLight() {
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
        let r = min(1, max(0, rgb[0] * brightness))
        let g = min(1, max(0, rgb[1] * brightness))
        let b = min(1, max(0, rgb[2] * brightness))
        controller?.light?.color = GCColor(red: Float(r), green: Float(g), blue: Float(b))
        previewLightColor = Color(red: r, green: g, blue: b)
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

private enum NikaidoStudioPage: String, CaseIterable {
    case lights = "Luces"
    case triggers = "Gatillos"
    case sticks = "Palancas"
    case profiles = "Perfiles"

    var symbol: String {
        switch self {
        case .lights: return "lightspectrum.horizontal"
        case .triggers: return "hand.point.up.left.fill"
        case .sticks: return "scope"
        case .profiles: return "square.stack.3d.up.fill"
        }
    }
}

private enum NikaidoTriggerSide {
    case left, right
}

@available(iOS 16.0, *)
struct BloomBoxNikaidoControllerView: View {
    let gameID: String
    let gameName: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var host = NikaidoGameControllerHost()
    @State private var page: NikaidoStudioPage = .lights
    @State private var selectedTrigger: NikaidoTriggerSide = .right
    @State private var demoPlayback = true
    @State private var selectedPreset = "custom"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    studioHeader
                    liveDualSense
                    studioTabs

                    Group {
                        switch page {
                        case .lights: lightingStudio
                        case .triggers: triggerStudio
                        case .sticks: stickStudio
                        case .profiles: profilesStudio
                        }
                    }
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: page)

                    Text("GameBox controla y previsualiza las funciones compatibles del DualSense. Algunos emuladores pueden sobrescribir luces y gatillos. El remapeo y drift todavía no modifican la entrada de los juegos invitados.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.48))
                        .padding(.horizontal, 5)
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
            .background {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.06, blue: 0.12),
                        Color(red: 0.01, green: 0.02, blue: 0.05)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Nikaido Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                        .foregroundStyle(.cyan)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear { host.activate(gameKey: gameID) }
            .onDisappear { host.deactivate() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                host.deactivate()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                host.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect)) { _ in host.refresh() }
            .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)) { _ in host.refresh() }
            .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
                host.sampleInput()
            }
        }
    }

    private var studioHeader: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 13).fill(.cyan.opacity(0.14))
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 21))
                    .foregroundStyle(.cyan)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(gameName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(host.controllerName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Label(host.batteryText, systemImage: "battery.75")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                HStack(spacing: 5) {
                    Circle().fill(host.isDualSense ? .green : .orange)
                        .frame(width: 6, height: 6)
                    Text(host.isDualSense ? "DualSense" : "Vista previa")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var liveDualSense: some View {
        TimelineView(.periodic(from: .now, by: 0.12)) { timeline in
            let tick = timeline.date.timeIntervalSinceReferenceDate
            let demoPress = Float(reduceMotion || !demoPlayback ? 0 : (0.5 + 0.5 * sin(tick * 1.7)))
            BloomBoxDualSenseVisualPreview(
                lightColor: host.previewLightColor,
                lightEffectName: host.profile.lightStyle.title,
                leftPressure: host.isDualSense ? host.leftTriggerRaw : demoPress,
                rightPressure: host.isDualSense ? host.rightTriggerRaw : demoPress,
                leftStrength: host.profile.leftStrength,
                rightStrength: host.profile.rightStrength,
                leftEnabled: host.profile.leftTriggerStyle != .off,
                rightEnabled: host.profile.rightTriggerStyle != .off,
                leftStick: host.isDualSense ? host.leftRaw : (0, 0),
                rightStick: host.isDualSense ? host.rightRaw : (0, 0),
                connected: host.isDualSense,
                onLightTap: { page = .lights },
                onLeftTriggerTap: { selectedTrigger = .left; page = .triggers },
                onRightTriggerTap: { selectedTrigger = .right; page = .triggers },
                onStickTap: { page = .sticks }
            )
        }
        .overlay(alignment: .bottomTrailing) {
            if !host.isDualSense && !reduceMotion {
                Button {
                    demoPlayback.toggle()
                } label: {
                    Label(demoPlayback ? "Pausar demo" : "Reproducir demo",
                          systemImage: demoPlayback ? "pause.fill" : "play.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(11)
                .accessibilityIdentifier("bloombox.nikaido.preview.playback")
            }
        }
    }

    private var studioTabs: some View {
        HStack(spacing: 6) {
            ForEach(NikaidoStudioPage.allCases, id: \.self) { item in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        page = item
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.symbol).font(.system(size: 17, weight: .medium))
                        Text(item.rawValue).font(.system(size: 10, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .foregroundStyle(page == item ? .white : .white.opacity(0.6))
                    .background(page == item ? Color.cyan.opacity(0.24) :
                                Color.white.opacity(0.055),
                                in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(page == item ? .cyan.opacity(0.7) : .clear,
                                      lineWidth: 1.2))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(page == item ? .isSelected : [])
            }
        }
        .accessibilityIdentifier("bloombox.nikaido.studio.tabs")
    }

    private var lightingStudio: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("RGB Studio", subtitle: "12 efectos que se reflejan en el control de arriba",
                         symbol: "lightspectrum.horizontal")
            studioCard {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                    GridItem(.flexible())], spacing: 9) {
                    ForEach(NikaidoLightStyle.allCases, id: \.self) { item in
                        lightCell(item)
                    }
                }
            }
            studioCard {
                HStack {
                    Label("Colores", systemImage: "paintpalette")
                        .font(.headline)
                    Spacer()
                    Text(host.profile.lightStyle.title)
                        .font(.caption).foregroundStyle(.cyan)
                }
                HStack(spacing: 16) {
                    ColorPicker("Principal", selection: colorBinding(primary: true), supportsOpacity: false)
                    ColorPicker("Secundario", selection: colorBinding(primary: false), supportsOpacity: false)
                }
                settingsSlider("Brillo", value: binding(\.lightBrightness), range: 0...1,
                               valueText: "\(Int(host.profile.lightBrightness * 100))%")
                settingsSlider("Velocidad", value: binding(\.lightSpeed), range: 0.25...3,
                               valueText: String(format: "%.1fx", host.profile.lightSpeed))
                    .disabled(!host.profile.lightStyle.animated)
            }
            .disabled(!host.supportsLight && host.isDualSense)
            Text(host.supportsLight ? "El DualSense tiene una sola barra RGB; el brillo y el color cambian juntos." :
                 "Modo demostración: los efectos animan el control dibujado. Conecta un DualSense compatible para probar las luces reales.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var triggerStudio: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Adaptive Trigger Studio",
                         subtitle: "Selecciona L2 o R2 directamente en el control",
                         symbol: "hand.point.up.left.fill")

            HStack(spacing: 10) {
                triggerSideButton(.left, name: "L2", effect: host.profile.leftTriggerStyle,
                                  strength: host.profile.leftStrength)
                triggerSideButton(.right, name: "R2", effect: host.profile.rightTriggerStyle,
                                  strength: host.profile.rightStrength)
            }
            studioCard {
                Label("11 sensaciones", systemImage: "waveform.path")
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                    ForEach(NikaidoTriggerStyle.allCases, id: \.self) { item in
                        triggerEffectCard(item)
                    }
                }
            }
            studioCard {
                Label(selectedTrigger == .left ? "Ajustar L2" : "Ajustar R2",
                      systemImage: "slider.horizontal.3")
                    .font(.headline)
                let strength = selectedTrigger == .left ? host.profile.leftStrength : host.profile.rightStrength
                let start = selectedTrigger == .left ? host.profile.leftStart : host.profile.rightStart
                settingsSlider("Resistencia", value: selectedTriggerStrength, range: 0...1,
                               valueText: "\(Int(strength * 100))%")
                settingsSlider("Inicio", value: selectedTriggerStart, range: 0.05...0.65,
                               valueText: "\(Int(start * 100))%")
                triggerResponseGraph(start: start, strength: strength)
                HStack {
                    Button("Copiar al otro gatillo") {
                        host.change { p in
                            if selectedTrigger == .left {
                                p.rightTriggerStyle = p.leftTriggerStyle
                                p.rightStrength = p.leftStrength
                                p.rightStart = p.leftStart
                            } else {
                                p.leftTriggerStyle = p.rightTriggerStyle
                                p.leftStrength = p.rightStrength
                                p.leftStart = p.rightStart
                            }
                        }
                    }
                    Spacer()
                    Button("Apagar ambos") {
                        host.change { p in
                            p.leftTriggerStyle = .off
                            p.rightTriggerStyle = .off
                        }
                    }
                }
                .font(.system(size: 12, weight: .semibold))
            }
            Text("Los gatillos físicos requieren un DualSense conectado. Su comportamiento puede ser reemplazado por un juego.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var stickStudio: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("Input Studio", subtitle: "Mide el drift y mira las palancas en vivo",
                         symbol: "scope")
            studioCard {
                Label("Autocalibración de drift", systemImage: "dot.scope")
                    .font(.headline)
                Text("Deja el control quieto y suelta ambas palancas durante la medición.")
                    .font(.caption).foregroundStyle(.white.opacity(0.64))
                if host.calibrating {
                    ProgressView(value: host.calibrationProgress)
                        .tint(.cyan)
                    Button("Cancelar") { host.cancelCalibration() }
                } else {
                    Button {
                        host.beginCalibration()
                    } label: {
                        Label("Medir y calibrar centro", systemImage: "scope")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!host.isDualSense)
                }
                Text(host.calibrationMessage)
                    .font(.caption).foregroundStyle(.white.opacity(0.6))
                Button("Borrar compensación de drift") {
                    host.change { p in
                        p.leftDriftX = 0; p.leftDriftY = 0
                        p.rightDriftX = 0; p.rightDriftY = 0
                    }
                }
                .font(.caption)
                .disabled(host.calibrating)
            }
            studioCard {
                stickRow("Palanca izquierda", deadzone: \.leftDeadzone,
                         sensitivity: \.leftSensitivity, invert: \.invertLeftY,
                         offsetX: \.leftDriftX, offsetY: \.leftDriftY,
                         physical: host.leftRaw)
            }
            studioCard {
                stickRow("Palanca derecha", deadzone: \.rightDeadzone,
                         sensitivity: \.rightSensitivity, invert: \.invertRightY,
                         offsetX: \.rightDriftX, offsetY: \.rightDriftY,
                         physical: host.rightRaw)
            }
            studioCard {
                Label("Remapeo guardado", systemImage: "arrow.left.arrow.right")
                    .font(.headline)
                mappingRow("Cruz (×)", key: \.crossMapping)
                mappingRow("Círculo (○)", key: \.circleMapping)
            }
            Text("Las zonas muertas y el remapeo se previsualizan y guardan por juego. Para afectar a un emulador se necesita su puente de entradas. Esto no repara drift físico.")
                .font(.caption).foregroundStyle(.white.opacity(0.55))
        }
    }

    private var profilesStudio: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("Perfiles", subtitle: "Un estilo para cada tipo de juego",
                         symbol: "square.stack.3d.up.fill")
            studioCard {
                Label(gameName, systemImage: "gamecontroller.fill")
                    .font(.headline).lineLimit(1)
                Text("Se guarda automáticamente. Cambiar de perfil conserva las compensaciones de drift.")
                    .font(.caption).foregroundStyle(.white.opacity(0.6))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    profileCard("default", title: "Por defecto", symbol: "circle.grid.2x2", tint: .cyan)
                    profileCard("shooter", title: "Shooter", symbol: "scope", tint: .orange)
                    profileCard("precision", title: "Precisión", symbol: "target", tint: .mint)
                    profileCard("racing", title: "Carreras", symbol: "car.fill", tint: .blue)
                    profileCard("archery", title: "Aventura", symbol: "leaf.fill", tint: .green)
                    profileCard("horror", title: "Horror", symbol: "moon.stars.fill", tint: .purple)
                    profileCard("arcade", title: "Arcade", symbol: "sparkles", tint: .pink)
                    profileCard("soft", title: "Suave", symbol: "hand.raised.fill", tint: .teal)
                }
            }
            Button(role: .destructive) {
                host.change { $0 = NikaidoGameProfile() }
                selectedPreset = "default"
            } label: {
                Label("Restaurar todos los ajustes del juego", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func sectionTitle(_ title: String, subtitle: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.cyan)
                .frame(width: 27)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 3)
    }

    private func studioCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13, content: content)
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white)
            .background(Color.white.opacity(0.065),
                        in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 19)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1))
    }

    private func settingsSlider(_ title: String, value: Binding<Double>,
                                range: ClosedRange<Double>, valueText: String) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 12, weight: .medium))
                .frame(width: 78, alignment: .leading)
            Slider(value: value, in: range)
                .tint(.cyan)
            Text(valueText)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .frame(width: 45, alignment: .trailing)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var selectedTriggerStrength: Binding<Double> {
        Binding(
            get: { selectedTrigger == .left ? host.profile.leftStrength : host.profile.rightStrength },
            set: { value in
                host.change { p in
                    if selectedTrigger == .left { p.leftStrength = value }
                    else { p.rightStrength = value }
                }
            }
        )
    }

    private var selectedTriggerStart: Binding<Double> {
        Binding(
            get: { selectedTrigger == .left ? host.profile.leftStart : host.profile.rightStart },
            set: { value in
                host.change { p in
                    if selectedTrigger == .left { p.leftStart = value }
                    else { p.rightStart = value }
                }
            }
        )
    }

    private func triggerSideButton(_ side: NikaidoTriggerSide, name: String,
                                   effect: NikaidoTriggerStyle, strength: Double) -> some View {
        let selected = selectedTrigger == side
        return Button {
            selectedTrigger = side
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(name).font(.system(size: 22, weight: .black, design: .rounded))
                    Spacer()
                    Image(systemName: "hand.point.up.left")
                        .font(.system(size: 15))
                }
                Text(effect.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1).minimumScaleFactor(0.75)
                GeometryReader { geo in
                    Capsule().fill(.white.opacity(0.12))
                        .overlay(alignment: .leading) {
                            Capsule().fill(selected ? .cyan : .white.opacity(0.45))
                                .frame(width: geo.size.width * min(1, max(0, strength)))
                        }
                }
                .frame(height: 4)
            }
            .padding(14)
            .foregroundStyle(selected ? .white : .white.opacity(0.7))
            .frame(maxWidth: .infinity)
            .background(selected ? Color.cyan.opacity(0.16) : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(selected ? .cyan : .white.opacity(0.1),
                              lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func triggerEffectCard(_ effect: NikaidoTriggerStyle) -> some View {
        let selectedStyle = selectedTrigger == .left ?
            host.profile.leftTriggerStyle : host.profile.rightTriggerStyle
        let selected = effect == selectedStyle
        return Button {
            host.change { p in
                if selectedTrigger == .left { p.leftTriggerStyle = effect }
                else { p.rightTriggerStyle = effect }
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: effect.symbol)
                        .font(.system(size: 18))
                        .foregroundStyle(selected ? .cyan : .white.opacity(0.75))
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.cyan)
                    }
                }
                Text(effect.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.75)
                Text(effect.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.53))
                    .lineLimit(2)
                    .frame(height: 26, alignment: .topLeading)
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
            .background(selected ? Color.cyan.opacity(0.14) : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13)
                .strokeBorder(selected ? .cyan.opacity(0.9) : .white.opacity(0.08),
                              lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func triggerResponseGraph(start: Double, strength: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vista previa de resistencia")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<19, id: \.self) { index in
                    let position = Double(index) / 18
                    let amplitude = position < start ? 0.04 :
                        min(1, 0.12 + strength * ((position - start) / max(0.1, 1 - start)))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(position < start ? Color.white.opacity(0.11) : Color.cyan.opacity(0.35 + amplitude * 0.65))
                        .frame(maxWidth: .infinity)
                        .frame(height: 7 + amplitude * 31)
                }
            }
            .frame(height: 38, alignment: .bottom)
            HStack {
                Text("Inicio")
                Spacer()
                Text("Presión final")
            }
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.4))
        }
        .padding(11)
        .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private func profileCard(_ id: String, title: String, symbol: String,
                             tint: Color) -> some View {
        let selected = selectedPreset == id
        return Button {
            applyPreset(id)
            selectedPreset = id
        } label: {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 23))
                        .foregroundStyle(tint)
                    Spacer()
                    if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(tint) }
                }
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(selected ? "Seleccionado" : "Aplicar perfil")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, minHeight: 91, alignment: .leading)
            .padding(12)
            .background(selected ? tint.opacity(0.16) : Color.white.opacity(0.055),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(selected ? tint.opacity(0.85) : .white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
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

    private var lightPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(
                    colors: [
                        host.previewLightColor,
                        Color(red: host.profile.secondaryRed, green: host.profile.secondaryGreen,
                              blue: host.profile.secondaryBlue)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            RoundedRectangle(cornerRadius: 18).fill(.black.opacity(0.27))
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 40, weight: .semibold))
                VStack(alignment: .leading, spacing: 4) {
                    Text(host.profile.lightStyle.title).font(.title3.bold())
                    Text("Vista previa · RGB Studio").font(.caption)
                        .foregroundStyle(.white.opacity(0.83))
                }
                Spacer()
                Image(systemName: host.profile.lightStyle.symbol).font(.title2)
            }
            .foregroundStyle(.white).padding(18)
        }
        .frame(height: 100)
    }

    private func lightCell(_ style: NikaidoLightStyle) -> some View {
        let selected = host.profile.lightStyle == style
        return Button {
            host.change { $0.lightStyle = style }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(LinearGradient(
                            colors: [
                                selected ? host.previewLightColor : Color(red: host.profile.red,
                                                                          green: host.profile.green,
                                                                          blue: host.profile.blue),
                                Color(red: host.profile.secondaryRed, green: host.profile.secondaryGreen,
                                      blue: host.profile.secondaryBlue).opacity(0.6)
                            ],
                            startPoint: .leading, endPoint: .trailing
                        ))
                    Image(systemName: style.symbol)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 4)
                }
                .frame(height: 48)
                Text(style.title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                HStack(spacing: 4) {
                    Circle()
                        .fill(selected ? Color.cyan : Color.white.opacity(0.3))
                        .frame(width: 5, height: 5)
                    Text(selected ? "Activo" : "Probar")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.cyan.opacity(0.15) : Color.white.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13)
                .strokeBorder(selected ? Color.cyan : Color.white.opacity(0.09), lineWidth: 1.2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func colorBinding(primary: Bool) -> Binding<Color> {
        Binding(
            get: {
                if primary {
                    return Color(red: host.profile.red, green: host.profile.green, blue: host.profile.blue)
                }
                return Color(red: host.profile.secondaryRed, green: host.profile.secondaryGreen,
                             blue: host.profile.secondaryBlue)
            },
            set: { color in
                let ui = UIColor(color)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return }
                host.change { profile in
                    if primary {
                        profile.red = Double(r); profile.green = Double(g); profile.blue = Double(b)
                    } else {
                        profile.secondaryRed = Double(r)
                        profile.secondaryGreen = Double(g)
                        profile.secondaryBlue = Double(b)
                    }
                }
            }
        )
    }

    @ViewBuilder
    private func triggerRow(
        _ title: String, style: WritableKeyPath<NikaidoGameProfile, NikaidoTriggerStyle>,
        strength: WritableKeyPath<NikaidoGameProfile, Double>,
        start: WritableKeyPath<NikaidoGameProfile, Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(title, systemImage: "pianokeys").font(.headline)
                Spacer()
                Text(host.profile[keyPath: style].detail)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Picker("Sensación", selection: binding(style)) {
                ForEach(NikaidoTriggerStyle.allCases, id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }.pickerStyle(.menu)
            HStack {
                Text("Fuerza")
                Slider(value: binding(strength), in: 0...1)
                Text("\(Int(host.profile[keyPath: strength] * 100))%")
                    .monospacedDigit().frame(width: 46)
            }
            HStack {
                Text("Inicio")
                Slider(value: binding(start), in: 0.05...0.65)
                Text("\(Int(host.profile[keyPath: start] * 100))%")
                    .monospacedDigit().frame(width: 46)
            }
        }
        .font(.subheadline).padding(10)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .disabled(!host.isDualSense)
    }

    @ViewBuilder
    private func stickRow(
        _ title: String,
        deadzone: WritableKeyPath<NikaidoGameProfile, Double>,
        sensitivity: WritableKeyPath<NikaidoGameProfile, Double>,
        invert: WritableKeyPath<NikaidoGameProfile, Bool>,
        offsetX: WritableKeyPath<NikaidoGameProfile, Double>,
        offsetY: WritableKeyPath<NikaidoGameProfile, Double>,
        physical: (Float, Float)
    ) -> some View {
        let output = NikaidoGameProfile.shaped(
            x: physical.0, y: physical.1, deadzone: host.profile[keyPath: deadzone],
            sensitivity: host.profile[keyPath: sensitivity], invertY: host.profile[keyPath: invert],
            offsetX: host.profile[keyPath: offsetX], offsetY: host.profile[keyPath: offsetY]
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
            Text(String(format: "Centro: %+.3f, %+.3f · Físico: %.2f, %.2f",
                        host.profile[keyPath: offsetX], host.profile[keyPath: offsetY],
                        physical.0, physical.1))
                .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
            Text(String(format: "Resultado ajustado: %.2f, %.2f", output.0, output.1))
                .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
        }.font(.subheadline)
    }

    private func applyPreset(_ name: String) {
        host.change { p in
            // Preserve calibration and remapping when switching presets.
            p.leftTriggerStyle = .off
            p.rightTriggerStyle = .off
            p.leftStrength = 0.45
            p.rightStrength = 0.45
            p.leftStart = 0.25
            p.rightStart = 0.25
            switch name {
            case "shooter":
                p.rightTriggerStyle = .weapon
                p.rightStrength = 0.65
                p.lightStyle = .pulse
                p.red = 0.18; p.green = 0.75; p.blue = 1
                p.rightSensitivity = 1.25
            case "precision":
                p.rightTriggerStyle = .sniper
                p.rightStrength = 0.7
                p.lightStyle = .fixed
                p.rightSensitivity = 0.8
            case "racing":
                p.leftTriggerStyle = .ramp
                p.rightTriggerStyle = .heavy
                p.leftStrength = 0.5; p.rightStrength = 0.65
                p.lightStyle = .wave
            case "archery":
                p.rightTriggerStyle = .bow
                p.rightStrength = 0.7
                p.lightStyle = .aurora
            case "horror":
                p.leftTriggerStyle = .resistance
                p.rightTriggerStyle = .recoil
                p.lightStyle = .heartbeat
            case "arcade":
                p.leftTriggerStyle = .soft
                p.rightTriggerStyle = .rapid
                p.lightStyle = .rainbow
            case "soft":
                p.leftTriggerStyle = .soft
                p.rightTriggerStyle = .soft
                p.leftStrength = 0.2; p.rightStrength = 0.2
                p.lightStyle = .breathe
            default:
                p.lightStyle = .fixed
                p.red = 0.25; p.green = 0.57; p.blue = 1
                p.leftSensitivity = 1; p.rightSensitivity = 1
            }
        }
    }

    private func mappingRow(_ title: String,
                            key: WritableKeyPath<NikaidoGameProfile, String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .medium))
            HStack(spacing: 5) {
                ForEach(["A", "B", "X", "Y", "none"], id: \.self) { value in
                    let selected = host.profile[keyPath: key] == value
                    Button {
                        host.change { $0[keyPath: key] = value }
                    } label: {
                        Text(value == "none" ? "—" : value)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .foregroundStyle(selected ? Color.white : Color.white.opacity(0.55))
                            .background(selected ? Color.cyan.opacity(0.28) : Color.white.opacity(0.055),
                                        in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .strokeBorder(selected ? Color.cyan : Color.clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(value == "none" ? "Desactivado" : value)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

}
