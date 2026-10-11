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

    /// App Group que se usa de verdad: el primero de los candidatos al que este proceso
    /// tiene acceso.
    ///
    /// Al firmar el IPA, herramientas como AltStore, SideStore o Sideloadly suelen
    /// cambiar el identificador del App Group (p. ej. añadiendo el ID del equipo). En
    /// ese caso el de `AppGroupIdentifier` ya no existe, y la app y el teclado guardaban
    /// cada uno en su propio almacenamiento sin verse. Por eso se prueban también los
    /// grupos que AltStore anota en `ALTAppGroups` y los del perfil de aprovisionamiento.
    static let appGroupIdentifier: String? = {
        let candidates = ConfigurationStorage.appGroupCandidates
        let accessible = candidates.first(where: { group in
            guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
                return false
            }
            return FileManager.default.fileExists(atPath: url.path)
        })
        return accessible ?? candidates.first
    }()

    /// Indica si el App Group está disponible en este proceso.
    static var isAppGroupAvailable: Bool { containerURL != nil }

    private static var appGroupCandidates: [String] {
        var candidates: [String] = []
        if let configured = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String {
            candidates.append(configured)
        }
        if let altGroups = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] {
            candidates += altGroups
        }
        candidates += provisionedAppGroups
        var seen = Set<String>()
        return candidates.filter { !$0.isEmpty && !$0.contains("*") && seen.insert($0).inserted }
    }

    /// Grupos de `embedded.mobileprovision`, que refleja los permisos con los que se firmó.
    private static var provisionedAppGroups: [String] {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data.subdata(in: start.lowerBound..<end.upperBound), format: nil
              ) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String]
        else { return [] }
        return groups
    }

    static var defaults: UserDefaults {
        if let group = appGroupIdentifier, let shared = UserDefaults(suiteName: group) {
            return shared
        }
        return .standard
    }

    /// Carpeta del App Group compartida entre la app y la extensión.
    static var containerURL: URL? {
        guard let group = appGroupIdentifier,
              let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group),
              FileManager.default.fileExists(atPath: url.path)
        else { return nil }
        return url
    }

    private static let keyboardAccessFileName = "keyboardAccess"

    /// Lo llama el teclado al aparecer, para que la app pueda comprobar que ambos
    /// comparten la misma carpeta.
    static func markKeyboardAccess() {
        guard let url = containerURL?.appendingPathComponent(keyboardAccessFileName) else { return }
        try? Data(ISO8601DateFormatter().string(from: Date()).utf8).write(to: url, options: .atomic)
    }

    /// Última vez que el teclado accedió a la carpeta compartida (nil si nunca).
    static var lastKeyboardAccess: Date? {
        guard let url = containerURL?.appendingPathComponent(keyboardAccessFileName),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return ISO8601DateFormatter().date(from: String(decoding: data, as: UTF8.self))
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
