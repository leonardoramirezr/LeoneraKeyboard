import AVFoundation

/// Graba el micrófono en archivos `.m4a`.
///
/// La sesión de audio (`start`/`stop`) va separada de cada grabación
/// (`beginCapture`/`finishCapture`) porque iOS no deja empezar a usar el micrófono
/// desde segundo plano: la app abre la sesión mientras está en primer plano y la
/// mantiene abierta para poder grabar cuando el teclado se lo pida.
///
/// Usar desde el hilo principal.
final class DictationRecorder {
    enum RecorderError: LocalizedError {
        case permissionDenied
        case noInput

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Leonera Keyboard no tiene permiso para usar el micrófono. Actívalo en Ajustes › Leonera Keyboard."
            case .noInput:
                return "No hay ningún micrófono disponible."
            }
        }
    }

    /// Resultado de una grabación.
    struct Capture {
        let url: URL
        /// Muestras escritas; 0 si el micrófono no entregó audio.
        let frames: AVAudioFramePosition
    }

    private let engine = AVAudioEngine()
    private var hasTap = false

    // Estado compartido con el hilo de audio.
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var fileURL: URL?
    private var frames: AVAudioFramePosition = 0

    var isRunning: Bool { engine.isRunning }

    static var hasPermission: Bool {
        AVAudioSession.sharedInstance().recordPermission == .granted
    }

    static func requestPermission(_ completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// Activa la sesión de audio y empieza a escuchar el micrófono (sin guardar nada).
    func start() throws {
        guard !engine.isRunning else { return }
        guard Self.hasPermission else { throw RecorderError.permissionDenied }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        do {
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw RecorderError.noInput }
            if hasTap { input.removeTap(onBus: 0) }
            input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
                self?.write(buffer)
            }
            hasTap = true
            engine.prepare()
            try engine.start()
        } catch {
            stop()
            throw error
        }
    }

    /// Descarta la grabación en curso y libera el micrófono.
    func stop() {
        _ = finishCapture()
        if hasTap {
            engine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Empieza a guardar el audio del micrófono en `url` (requiere `start()`).
    func beginCapture(to url: URL) throws {
        let format = engine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw RecorderError.noInput }
        try? FileManager.default.removeItem(at: url)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        let newFile = try AVAudioFile(
            forWriting: url,
            settings: settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
        lock.lock()
        file = newFile
        fileURL = url
        frames = 0
        lock.unlock()
    }

    /// Termina la grabación en curso y cierra el archivo. Devuelve nil si no se estaba grabando.
    func finishCapture() -> Capture? {
        lock.lock()
        let capture = fileURL.map { Capture(url: $0, frames: frames) }
        // Al soltar la última referencia, AVAudioFile termina de escribir y cierra el archivo.
        file = nil
        fileURL = nil
        frames = 0
        lock.unlock()
        return capture
    }

    private func write(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard let file else { return }
        do {
            try file.write(from: buffer)
            frames += AVAudioFramePosition(buffer.frameLength)
        } catch {
            // Se deja de escribir; `finishCapture` devolverá lo grabado hasta aquí.
            self.file = nil
        }
    }
}
