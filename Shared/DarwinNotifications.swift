import Foundation

/// Notificaciones Darwin: avisos sin contenido que cruzan procesos, usados para que
/// la app y la extensión del teclado se enteren de los cambios de la otra.
enum DarwinNotification {
    static func post(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil, nil, true
        )
    }
}

/// Llama a `handler` en el hilo principal cada vez que algún proceso envía la
/// notificación Darwin `name`.
final class DarwinNotificationObserver {
    private let handler: () -> Void

    init(name: String, handler: @escaping () -> Void) {
        self.handler = handler
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let this = Unmanaged<DarwinNotificationObserver>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { this.handler() }
            },
            name as CFString,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
}
