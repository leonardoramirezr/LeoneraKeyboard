import Foundation

/// Guarda la configuración en el contenedor del App Group para que la app
/// y la extensión del teclado compartan la misma distribución.
enum ConfigurationStorage {
    private static let key = "keyboardConfiguration"

    static var appGroupIdentifier: String? {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
    }

    static var defaults: UserDefaults {
        if let group = appGroupIdentifier, let shared = UserDefaults(suiteName: group) {
            return shared
        }
        return .standard
    }

    static func load() -> KeyboardConfiguration {
        guard let data = defaults.data(forKey: key),
              let configuration = try? JSONDecoder().decode(KeyboardConfiguration.self, from: data)
        else { return .default }
        return configuration
    }

    static func save(_ configuration: KeyboardConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        defaults.set(data, forKey: key)
    }
}
