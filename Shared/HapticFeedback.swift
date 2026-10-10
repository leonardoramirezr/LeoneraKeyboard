import CoreHaptics
import UIKit

/// Reproduce la vibración de las teclas según los ajustes (tipo, intensidad y duración).
///
/// Nunca bloquea al que la llama: el pulso breve se lanza en la siguiente vuelta del
/// hilo principal y la vibración con duración se prepara y reproduce en una cola
/// propia. La vibración sigue sonando por su cuenta mientras el teclado recibe la
/// siguiente pulsación, que corta la anterior en lugar de esperar a que termine.
///
/// Usar desde el hilo principal.
final class HapticFeedback {
    private var generators: [HapticStyle: UIImpactFeedbackGenerator] = [:]
    private let continuous = ContinuousHaptics()

    func play(_ settings: KeyboardSettings) {
        let style = settings.hapticStyle
        let intensity = min(max(settings.hapticIntensity, 0.1), 1)
        let duration = min(max(settings.hapticDuration, 0), 1000) / 1000

        guard duration > 0, ContinuousHaptics.isSupported else {
            DispatchQueue.main.async { self.impact(style, intensity: intensity) }
            return
        }
        continuous.play(style: style, intensity: intensity, duration: duration) { [weak self] in
            // Core Haptics no está disponible: se usa el pulso breve.
            DispatchQueue.main.async { self?.impact(style, intensity: intensity) }
        }
    }

    private func impact(_ style: HapticStyle, intensity: Double) {
        let generator: UIImpactFeedbackGenerator
        if let existing = generators[style] {
            generator = existing
        } else {
            generator = UIImpactFeedbackGenerator(style: style.impactStyle)
            generators[style] = generator
        }
        generator.impactOccurred(intensity: CGFloat(intensity))
        // Mantiene el motor háptico listo para la siguiente pulsación.
        generator.prepare()
    }
}

/// Vibraciones con duración mediante Core Haptics. Todo su estado vive en `queue`.
private final class ContinuousHaptics {
    static let isSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    private let queue = DispatchQueue(label: "com.leonera.keyboard.haptics", qos: .userInteractive)
    private var engine: CHHapticEngine?
    private var engineNeedsStart = true
    private var failedStarts = 0
    private var player: CHHapticPatternPlayer?

    func play(style: HapticStyle, intensity: Double, duration: TimeInterval, fallback: @escaping () -> Void) {
        queue.async {
            guard let engine = self.startedEngine() else { return fallback() }
            do {
                let event = CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity)),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: style.sharpness),
                    ],
                    relativeTime: 0,
                    duration: duration
                )
                let player = try engine.makePlayer(with: CHHapticPattern(events: [event], parameters: []))
                // La nueva pulsación corta la vibración anterior en lugar de esperar a que acabe.
                try? self.player?.stop(atTime: CHHapticTimeImmediate)
                try player.start(atTime: CHHapticTimeImmediate)
                self.player = player
            } catch {
                self.engineNeedsStart = true
                fallback()
            }
        }
    }

    /// Tras varios fallos seguidos se deja de intentar y se usa siempre el pulso breve.
    private func startedEngine() -> CHHapticEngine? {
        guard failedStarts < 3 else { return nil }
        do {
            let current = try self.engine ?? makeEngine()
            if engineNeedsStart {
                try current.start()
                engineNeedsStart = false
            }
            failedStarts = 0
            return current
        } catch {
            failedStarts += 1
            engineNeedsStart = true
            return nil
        }
    }

    private func makeEngine() throws -> CHHapticEngine {
        let engine = try CHHapticEngine()
        engine.playsHapticsOnly = true
        engine.isAutoShutdownEnabled = true
        engine.stoppedHandler = { [weak self] _ in
            self?.queue.async { self?.engineNeedsStart = true }
        }
        engine.resetHandler = { [weak self] in
            self?.queue.async { self?.engineNeedsStart = true }
        }
        self.engine = engine
        return engine
    }
}

private extension HapticStyle {
    var impactStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .original: return .light
        case .soft: return .soft
        case .rigid: return .rigid
        }
    }

    /// Nitidez en Core Haptics: baja se siente redondeada, alta se siente seca.
    var sharpness: Float {
        switch self {
        case .original: return 0.5
        case .soft: return 0.1
        case .rigid: return 1
        }
    }
}
