import Foundation
import GameController

/// Controller input is active only while a BloomBox screen owns focus.
/// Every previous gamepad handler is restored before a guest takes over.
@MainActor
final class BloomBoxControllerInput: ObservableObject {
    // Persisted notification spellings remain compatible with existing callers.
    static let pauseNotification = Notification.Name("LiveBoardPauseController")
    static let resumeNotification = Notification.Name("LiveBoardResumeController")

    enum Command: Equatable {
        case left, right, up, down
        case confirm, back, details, favorite
        case previousSection, nextSection
    }

    @Published private(set) var connected = false
    @Published private(set) var confirmSymbol = "a.circle"
    @Published private(set) var detailsSymbol = "x.circle"
    var onCommand: ((Command) -> Void)?

    private struct Binding {
        let gamepad: GCExtendedGamepad
        let priorHandler: GCExtendedGamepadValueChangedHandler?
    }

    private var enabled = false
    private var bindings: [Binding] = []
    private var notifications: [NSObjectProtocol] = []
    private var directionInProgress: Command?
    private var navigationRepeat: Task<Void, Never>?

    func start() {
        guard !enabled else { return }
        enabled = true
        GCController.controllers().forEach(attach)

        let center = NotificationCenter.default
        notifications.append(center.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] event in
            guard let device = event.object as? GCController else { return }
            Task { @MainActor [weak self] in self?.attach(device) }
        })
        notifications.append(center.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: .main
        ) { [weak self] event in
            guard let device = event.object as? GCController else { return }
            Task { @MainActor [weak self] in self?.detach(device) }
        })
    }

    func stop() {
        onCommand = nil
        guard enabled else { return }
        enabled = false
        clearNavigationRepeat()
        for binding in bindings {
            binding.gamepad.valueChangedHandler = binding.priorHandler
        }
        bindings.removeAll()
        let center = NotificationCenter.default
        notifications.forEach(center.removeObserver)
        notifications.removeAll()
        updateConnectionState()
    }

    func attach(_ controller: GCController) {
        guard enabled, let gamepad = controller.extendedGamepad else { return }
        guard !bindings.contains(where: { $0.gamepad === gamepad }) else { return }

        bindings.append(Binding(gamepad: gamepad, priorHandler: gamepad.valueChangedHandler))
        gamepad.valueChangedHandler = { [weak self] sender, element in
            Task { @MainActor [weak self] in
                self?.receiveChange(on: sender, element: element)
            }
        }
        updateConnectionState()
    }

    private func detach(_ device: GCController) {
        guard let gamepad = device.extendedGamepad else { return }
        guard let index = bindings.firstIndex(where: { $0.gamepad === gamepad }) else { return }
        let binding = bindings.remove(at: index)
        binding.gamepad.valueChangedHandler = binding.priorHandler
        clearNavigationRepeat()
        updateConnectionState()
    }

    private func updateConnectionState() {
        connected = !bindings.isEmpty
        confirmSymbol = bindings.last?.gamepad.buttonA.sfSymbolsName ?? "a.circle"
        detailsSymbol = bindings.last?.gamepad.buttonX.sfSymbolsName ?? "x.circle"
    }

    private func receiveChange(on pad: GCExtendedGamepad, element: GCControllerElement) {
        guard enabled else { return }

        if element === pad.dpad {
            navigate(x: pad.dpad.xAxis.value, y: pad.dpad.yAxis.value)
            return
        }
        if element === pad.leftThumbstick {
            navigate(x: pad.leftThumbstick.xAxis.value, y: pad.leftThumbstick.yAxis.value)
            return
        }

        let buttons: [(GCControllerButtonInput, Command)] = [
            (pad.buttonA, .confirm), (pad.buttonB, .back),
            (pad.buttonX, .details), (pad.buttonY, .favorite),
            (pad.leftShoulder, .previousSection),
            (pad.rightShoulder, .nextSection),
            (pad.buttonMenu, .details)
        ]
        if let pressed = buttons.first(where: { $0.0 === element && $0.0.isPressed }) {
            onCommand?(pressed.1)
        }
    }

    private static func direction(x: Float, y: Float) -> Command? {
        let horizontal = abs(x) >= abs(y)
        let strength = horizontal ? abs(x) : abs(y)
        guard strength >= 0.55 else { return nil }
        return horizontal ? (x > 0 ? .right : .left) : (y > 0 ? .up : .down)
    }

    private func clearNavigationRepeat() {
        navigationRepeat?.cancel()
        navigationRepeat = nil
        directionInProgress = nil
    }

    private func navigate(x: Float, y: Float) {
        let incoming = Self.direction(x: x, y: y)
        guard incoming != directionInProgress else { return }
        clearNavigationRepeat()
        guard let incoming else { return }

        directionInProgress = incoming
        onCommand?(incoming)
        navigationRepeat = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self else { return }
            while !Task.isCancelled && self.enabled && self.directionInProgress == incoming {
                self.onCommand?(incoming)
                try? await Task.sleep(nanoseconds: 140_000_000)
            }
        }
    }
}

struct BloomBoxGameBoxNavigation: Equatable {
    enum Focus: Equatable { case header, rail, launch, details }
    var selectedIndex = 0
    var headerIndex = 0
    var focus: Focus = .rail

    mutating func move(_ command: BloomBoxControllerInput.Command,
                       count: Int, headerCount: Int = 4) {
        switch (focus, command) {
        case (.header, .left):
            headerIndex = max(0, headerIndex - 1)
        case (.header, .right):
            headerIndex = min(max(0, headerCount - 1), headerIndex + 1)
        case (.rail, .left):
            selectedIndex = max(0, selectedIndex - 1)
        case (.rail, .right):
            selectedIndex = min(max(0, count - 1), selectedIndex + 1)
        case (.details, .left):
            focus = .launch
        case (.launch, .right):
            focus = .details
        case (_, .up):
            focus = focus == .rail ? .header : .rail
        case (_, .down):
            focus = focus == .header ? .rail : .launch
        case (_, .back):
            focus = .rail
        default:
            break
        }
    }
}

// Binary/API compatibility for host callers. Not a separate LiveBoard runtime.
typealias LiveBoardControllerInput = BloomBoxControllerInput
typealias LiveBoardConsoleNavigation = BloomBoxGameBoxNavigation
