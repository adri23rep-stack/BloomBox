// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 adri23rep-stack.
// Lightweight, vector-only visual model. This is a UI illustration,
// not a device firmware emulator or a claim of independent LED zones.
import SwiftUI

private struct BloomBoxDualSenseSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 112, y: 46))
        p.addCurve(to: CGPoint(x: 60, y: 58), control1: CGPoint(x: 82, y: 43), control2: CGPoint(x: 70, y: 47))
        p.addCurve(to: CGPoint(x: 29, y: 107), control1: CGPoint(x: 40, y: 69), control2: CGPoint(x: 35, y: 90))
        p.addCurve(to: CGPoint(x: 11, y: 183), control1: CGPoint(x: 18, y: 140), control2: CGPoint(x: 10, y: 165))
        p.addCurve(to: CGPoint(x: 55, y: 225), control1: CGPoint(x: 8, y: 224), control2: CGPoint(x: 29, y: 240))
        p.addCurve(to: CGPoint(x: 100, y: 173), control1: CGPoint(x: 75, y: 215), control2: CGPoint(x: 84, y: 188))
        p.addCurve(to: CGPoint(x: 151, y: 164), control1: CGPoint(x: 116, y: 161), control2: CGPoint(x: 131, y: 164))
        p.addLine(to: CGPoint(x: 249, y: 164))
        p.addCurve(to: CGPoint(x: 300, y: 173), control1: CGPoint(x: 269, y: 164), control2: CGPoint(x: 284, y: 161))
        p.addCurve(to: CGPoint(x: 345, y: 225), control1: CGPoint(x: 316, y: 188), control2: CGPoint(x: 325, y: 215))
        p.addCurve(to: CGPoint(x: 389, y: 183), control1: CGPoint(x: 371, y: 240), control2: CGPoint(x: 392, y: 224))
        p.addCurve(to: CGPoint(x: 371, y: 107), control1: CGPoint(x: 390, y: 165), control2: CGPoint(x: 382, y: 140))
        p.addCurve(to: CGPoint(x: 340, y: 58), control1: CGPoint(x: 365, y: 90), control2: CGPoint(x: 360, y: 69))
        p.addCurve(to: CGPoint(x: 288, y: 46), control1: CGPoint(x: 330, y: 47), control2: CGPoint(x: 318, y: 43))
        p.addCurve(to: CGPoint(x: 112, y: 46), control1: CGPoint(x: 260, y: 52), control2: CGPoint(x: 140, y: 52))
        p.closeSubpath()
        return p.applying(CGAffineTransform(scaleX: rect.width / 400, y: rect.height / 230))
    }
}

@available(iOS 16.0, *)
struct BloomBoxDualSenseVisualPreview: View {
    let lightColor: Color
    let lightEffectName: String
    let leftPressure: Float
    let rightPressure: Float
    let leftStrength: Double
    let rightStrength: Double
    let leftEnabled: Bool
    let rightEnabled: Bool
    let leftStick: (Float, Float)
    let rightStick: (Float, Float)
    let connected: Bool
    let onLightTap: () -> Void
    let onLeftTriggerTap: () -> Void
    let onRightTriggerTap: () -> Void

    private let cyan = Color(red: 0.25, green: 0.83, blue: 1)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack")
                    .foregroundStyle(cyan)
                Text("DUALSENSE LIVE STUDIO")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.25)
                Spacer()
                Circle()
                    .fill(connected ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(connected ? "CONECTADO" : "SIMULACIÓN")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }

            GeometryReader { geo in
                let scale = min(geo.size.width / 400, geo.size.height / 245)
                ZStack {
                    controllerArtwork
                        .frame(width: 400, height: 230)
                }
                .frame(width: 400, height: 245)
                .scaleEffect(scale, anchor: .center)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                .accessibilityElement(children: .contain)
            }
            .frame(height: 224)

            HStack(spacing: 10) {
                Circle().fill(lightColor).frame(width: 9, height: 9)
                    .shadow(color: lightColor.opacity(0.8), radius: 5)
                Text(lightEffectName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "hand.tap")
                Text("Toca luces o L2/R2")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
        .foregroundStyle(.white)
        .padding(15)
        .background {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(LinearGradient(colors: [
                    Color(red: 0.07, green: 0.10, blue: 0.17),
                    Color(red: 0.025, green: 0.035, blue: 0.065)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay(RoundedRectangle(cornerRadius: 23)
            .strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: lightColor.opacity(0.10), radius: 20, y: 6)
        .animation(.easeInOut(duration: 0.2), value: lightColor)
        .accessibilityIdentifier("bloombox.nikaido.dualsense-live-preview")
    }

    private var controllerArtwork: some View {
        ZStack {
            Ellipse()
                .fill(lightColor.opacity(0.16))
                .blur(radius: 28)
                .frame(width: 300, height: 95)
                .position(x: 200, y: 115)

            // Rear shoulder housing
            RoundedRectangle(cornerRadius: 17)
                .fill(Color(red: 0.09, green: 0.11, blue: 0.18))
                .frame(width: 332, height: 53)
                .position(x: 200, y: 63)

            BloomBoxDualSenseSilhouette()
                .fill(LinearGradient(colors: [
                    Color(red: 0.98, green: 0.99, blue: 1),
                    Color(red: 0.78, green: 0.82, blue: 0.91),
                    Color(red: 0.58, green: 0.65, blue: 0.76)
                ], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.5), radius: 14, y: 10)

            BloomBoxDualSenseSilhouette()
                .stroke(.white.opacity(0.7), lineWidth: 1.5)

            // Black center / touchpad housing.
            RoundedRectangle(cornerRadius: 36)
                .fill(Color(red: 0.09, green: 0.10, blue: 0.16))
                .frame(width: 208, height: 116)
                .position(x: 200, y: 105)

            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [
                    Color(red: 0.17, green: 0.19, blue: 0.28),
                    Color(red: 0.08, green: 0.09, blue: 0.15)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.18), lineWidth: 0.8))
                .frame(width: 126, height: 61)
                .position(x: 200, y: 94)

            // Real DualSense: single RGB light bar, shown along the touchpad edges.
            lightStrip(left: true)
            lightStrip(left: false)

            // L2/R2 physical input indicators, tappable to open the trigger studio.
            triggerButton("L2", x: 69, pressure: leftPressure,
                          strength: leftStrength, enabled: leftEnabled, action: onLeftTriggerTap)
            triggerButton("R2", x: 331, pressure: rightPressure,
                          strength: rightStrength, enabled: rightEnabled, action: onRightTriggerTap)

            dPad.position(x: 91, y: 128)
            faceButtons.position(x: 311, y: 128)

            analogStick(leftStick).position(x: 149, y: 163)
            analogStick(rightStick).position(x: 250, y: 163)

            Text("✦")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .position(x: 200, y: 153)

            Button(action: onLightTap) {
                RoundedRectangle(cornerRadius: 11)
                    .fill(.clear)
                    .frame(width: 150, height: 77)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 200, y: 97)
            .accessibilityLabel("Editar las luces del DualSense")
        }
        .frame(width: 400, height: 230)
    }

    private func lightStrip(left: Bool) -> some View {
        let path = Path { p in
            if left {
                p.move(to: CGPoint(x: 138, y: 70))
                p.addQuadCurve(to: CGPoint(x: 132, y: 137),
                               control: CGPoint(x: 124, y: 98))
            } else {
                p.move(to: CGPoint(x: 262, y: 70))
                p.addQuadCurve(to: CGPoint(x: 268, y: 137),
                               control: CGPoint(x: 276, y: 98))
            }
        }
        return path.stroke(lightColor, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
            .shadow(color: lightColor.opacity(0.9), radius: 8)
            .shadow(color: lightColor.opacity(0.6), radius: 13)
            .allowsHitTesting(false)
    }

    private func triggerButton(_ title: String, x: CGFloat, pressure: Float,
                               strength: Double, enabled: Bool,
                               action: @escaping () -> Void) -> some View {
        let fill = CGFloat(max(0, min(1, pressure)))
        return Button(action: action) {
            VStack(spacing: 3) {
                Text(title).font(.system(size: 11, weight: .black, design: .rounded))
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule()
                        .fill(enabled ? lightColor : Color.gray)
                        .frame(width: max(2, 51 * fill))
                }
                .frame(width: 51, height: 4)
            }
            .frame(width: 64, height: 31)
            .foregroundStyle(enabled ? lightColor : Color.white.opacity(0.72))
            .background(Color(red: 0.11, green: 0.14, blue: 0.20),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(enabled ? lightColor.opacity(0.6 + min(0.3, strength * 0.3)) :
                                      Color.white.opacity(0.15), lineWidth: 1.2))
            .shadow(color: enabled ? lightColor.opacity(strength * 0.25) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .position(x: x, y: 58)
        .accessibilityLabel("Configurar gatillo " + title)
    }

    private var dPad: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(red: 0.12, green: 0.15, blue: 0.22))
                .frame(width: 18, height: 57)
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(red: 0.12, green: 0.15, blue: 0.22))
                .frame(width: 57, height: 18)
            Image(systemName: "plus")
                .font(.system(size: 29, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.24))
        }
        .frame(width: 58, height: 58)
    }

    private var faceButtons: some View {
        ZStack {
            faceButton("△", x: 0, y: -23, color: .mint)
            faceButton("○", x: 23, y: 0, color: .pink)
            faceButton("×", x: 0, y: 23, color: .cyan)
            faceButton("□", x: -23, y: 0, color: .purple)
        }
        .frame(width: 75, height: 75)
    }

    private func faceButton(_ label: String, x: CGFloat, y: CGFloat, color: Color) -> some View {
        Text(label)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(color.opacity(0.85))
            .frame(width: 25, height: 25)
            .background(Color(red: 0.09, green: 0.11, blue: 0.17), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1))
            .offset(x: x, y: y)
    }

    private func analogStick(_ input: (Float, Float)) -> some View {
        let x = CGFloat(max(-1, min(1, input.0))) * 7
        let y = CGFloat(max(-1, min(1, input.1))) * -7
        return ZStack {
            Circle().fill(Color(red: 0.10, green: 0.11, blue: 0.17))
                .frame(width: 49, height: 49)
            Circle().stroke(.white.opacity(0.14), lineWidth: 2)
                .frame(width: 45, height: 45)
            Circle()
                .fill(RadialGradient(colors: [
                    Color(red: 0.24, green: 0.28, blue: 0.36),
                    Color(red: 0.12, green: 0.13, blue: 0.19)
                ], center: .topLeading, startRadius: 0, endRadius: 26))
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                .offset(x: x, y: y)
        }
        .frame(width: 52, height: 52)
        .accessibilityHidden(true)
    }
}
