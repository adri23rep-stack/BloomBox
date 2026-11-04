import SwiftUI

/// Empty destination for a future first-party BloomBox feature.
/// No guest, gamepad, JIT or SideStore runtime is mounted in this section.
struct BloomBoxReservedSection: View {
    let backToHome: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "square.dashed")
                    .font(.system(size: 56, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.65))
                    .accessibilityHidden(true)
                Text("Espacio reservado")
                    .font(.title2.weight(.semibold))
                Text("Esta sección está lista para una función nueva de BloomBox.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Button("Volver al escritorio", action: backToHome)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("bloombox.reserved.back")
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("bloombox.reserved.section")
    }
}
