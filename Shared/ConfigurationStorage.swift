import Foundation

/// Guarda la configuración en el contenedor del App Group para que la app
/// y la extensión del teclado compartan la misma distribución.
///
/// Se guarda como archivo JSON en el contenedor compartido porque la extensión
/// lo lee directamente del disco: `UserDefaults` mantiene una caché por proceso
/// y el teclado podía seguir viendo valores antiguos (p. ej. la vibración
/// activada) después de cambiarlos en la app. `UserDefaults` se mantiene como
/// respaldo y para leer configuraciones guardadas por versiones anteriores.
enum ConfigurationStorage {
    private static let key = "keyboardConfiguration"
    private static let fileName = "keyboardConfiguration.json"

    /// Notificación Darwin (entre procesos) que se envía cada vez que la app guarda.
    static let didChangeNotification = "com.leonera.keyboard.configurationDidChange"

    static var appGroupIdentifier: String? {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
    }

    static var defaults: UserDefaults {
        if let group = appGroupIdentifier, let shared = UserDefaults(suiteName: group) {
            return shared
        }
        return .standard
    }

    /// Carpeta del App Group compartida entre la app y la extensión.
    static var containerURL: URL? {
        guard let group = appGroupIdentifier else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
    }

    private static var fileURL: URL? {
        containerURL?.appendingPathComponent(fileName)
    }

    static func load() -> KeyboardConfiguration {
        if let url = fileURL, let data = try? Data(contentsOf: url), let configuration = decode(data) {
            return configuration
        }
        if let data = defaults.data(forKey: key), let configuration = decode(data) {
            return configuration
        }
        return .default
    }

    static func save(_ configuration: KeyboardConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        if let url = fileURL {
            try? data.write(to: url, options: .atomic)
        }
        defaults.set(data, forKey: key)
        DarwinNotification.post(didChangeNotification)
    }

    private static func decode(_ data: Data) -> KeyboardConfiguration? {
        try? JSONDecoder().decode(KeyboardConfiguration.self, from: data)
    }
}
