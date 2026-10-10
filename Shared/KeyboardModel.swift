import Foundation

/// Tipos de acción que puede tener una tecla, ya sea al tocarla (acción principal)
/// o al deslizarla hacia abajo (acción secundaria).
enum KeyActionType: String, Codable, CaseIterable, Identifiable {
    case character
    case space
    case backspace
    case deleteWord
    case shift
    case capsLock
    case returnKey
    case tab
    case dismissKeyboard
    case nextKeyboard
    case emoji
    case paste
    case copy
    case cut
    case cursorLeft
    case cursorRight
    case none

    var id: String { rawValue }

    /// Nombre legible para el editor.
    var displayName: String {
        switch self {
        case .character: return "Texto"
        case .space: return "Espacio"
        case .backspace: return "Borrar"
        case .deleteWord: return "Borrar palabra"
        case .shift: return "Mayúsculas"
        case .capsLock: return "Bloq. mayúsculas"
        case .returnKey: return "Intro"
        case .tab: return "Tabulador"
        case .dismissKeyboard: return "Ocultar teclado"
        case .nextKeyboard: return "Siguiente teclado"
        case .emoji: return "Emojis"
        case .paste: return "Pegar"
        case .copy: return "Copiar selección"
        case .cut: return "Cortar selección"
        case .cursorLeft: return "Cursor a la izquierda"
        case .cursorRight: return "Cursor a la derecha"
        case .none: return "Ninguna"
        }
    }

    /// Símbolo SF usado para dibujar la acción (nil para texto o espacio).
    var systemImage: String? {
        switch self {
        case .character, .space, .none: return nil
        case .backspace: return "delete.left"
        case .deleteWord: return "delete.left.fill"
        case .shift: return "shift"
        case .capsLock: return "capslock"
        case .returnKey: return "return"
        case .tab: return "arrow.right.to.line"
        case .dismissKeyboard: return "keyboard.chevron.compact.down"
        case .nextKeyboard: return "globe"
        case .emoji: return "face.smiling"
        case .paste: return "doc.on.clipboard"
        case .copy: return "doc.on.doc"
        case .cut: return "scissors"
        case .cursorLeft: return "arrow.left"
        case .cursorRight: return "arrow.right"
        }
    }

    /// Acciones que se repiten mientras se mantiene pulsada la tecla.
    var repeatsWhileHeld: Bool {
        switch self {
        case .backspace, .deleteWord, .cursorLeft, .cursorRight: return true
        default: return false
        }
    }

    /// Las teclas de función se dibujan con fondo gris.
    var isFunctionKey: Bool {
        switch self {
        case .character, .space: return false
        default: return true
        }
    }
}

struct KeyAction: Codable, Hashable {
    var type: KeyActionType
    /// Texto a insertar cuando `type == .character`.
    var text: String

    init(_ type: KeyActionType, text: String = "") {
        self.type = type
        self.text = text
    }

    static func character(_ text: String) -> KeyAction { KeyAction(.character, text: text) }

    private enum CodingKeys: String, CodingKey { case type, text }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? container.decode(KeyActionType.self, forKey: .type)) ?? .none
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        if type == .character {
            try container.encode(text, forKey: .text)
        }
    }

    /// Descripción corta para listas del editor.
    var summary: String {
        type == .character ? "“\(text)”" : type.displayName
    }
}

struct KeyDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    /// Acción al tocar la tecla.
    var primary: KeyAction
    /// Acción al deslizar la tecla hacia abajo (símbolo pequeño en la parte superior).
    var secondary: KeyAction?
    /// Ancho relativo (1 = una tecla de letra).
    var width: Double
    /// Etiqueta personalizada para la acción principal (opcional).
    var label: String?

    init(id: UUID = UUID(), primary: KeyAction, secondary: KeyAction? = nil, width: Double = 1, label: String? = nil) {
        self.id = id
        self.primary = primary
        self.secondary = secondary
        self.width = width
        self.label = label
    }

    private enum CodingKeys: String, CodingKey { case id, primary, secondary, width, label }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        primary = try container.decode(KeyAction.self, forKey: .primary)
        secondary = try container.decodeIfPresent(KeyAction.self, forKey: .secondary)
        let decodedWidth = try container.decodeIfPresent(Double.self, forKey: .width) ?? 1
        width = max(0.25, decodedWidth)
        label = try container.decodeIfPresent(String.self, forKey: .label)
    }

    var summary: String {
        var text = label.map { "“\($0)”" } ?? primary.summary
        if let secondary, secondary.type != .none {
            text += "  ↓ " + secondary.summary
        }
        return text
    }
}

struct KeyRow: Codable, Hashable, Identifiable {
    var id: UUID
    var keys: [KeyDefinition]

    init(id: UUID = UUID(), keys: [KeyDefinition]) {
        self.id = id
        self.keys = keys
    }

    private enum CodingKeys: String, CodingKey { case id, keys }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        keys = try container.decodeIfPresent([KeyDefinition].self, forKey: .keys) ?? []
    }

    var totalUnits: Double { keys.reduce(0) { $0 + $1.width } }
}

struct KeyboardLayout: Codable, Hashable {
    var name: String
    var rows: [KeyRow]
}

struct KeyboardSettings: Codable, Hashable {
    /// Activa mayúsculas automáticamente al empezar una frase.
    var autoCapitalize = true
    /// Muestra las letras en minúscula cuando las mayúsculas están desactivadas.
    var showLowercase = true
    /// Vibración al pulsar (requiere acceso completo).
    var haptics = true
    /// Sonido al pulsar (requiere acceso completo).
    var keyClicks = false
    /// Alto de cada fila en puntos.
    var rowHeight: Double = 48
    /// Distancia en puntos que hay que deslizar hacia abajo para activar la acción secundaria.
    var swipeThreshold: Double = 18

    init() {}

    private enum CodingKeys: String, CodingKey {
        case autoCapitalize, showLowercase, haptics, keyClicks, rowHeight, swipeThreshold
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = KeyboardSettings()
        autoCapitalize = try container.decodeIfPresent(Bool.self, forKey: .autoCapitalize) ?? defaults.autoCapitalize
        showLowercase = try container.decodeIfPresent(Bool.self, forKey: .showLowercase) ?? defaults.showLowercase
        haptics = try container.decodeIfPresent(Bool.self, forKey: .haptics) ?? defaults.haptics
        keyClicks = try container.decodeIfPresent(Bool.self, forKey: .keyClicks) ?? defaults.keyClicks
        rowHeight = try container.decodeIfPresent(Double.self, forKey: .rowHeight) ?? defaults.rowHeight
        swipeThreshold = try container.decodeIfPresent(Double.self, forKey: .swipeThreshold) ?? defaults.swipeThreshold
    }
}

/// Todo lo que se comparte entre la app y la extensión del teclado.
struct KeyboardConfiguration: Codable, Hashable {
    var version = 1
    var layout: KeyboardLayout
    var settings: KeyboardSettings

    init(layout: KeyboardLayout, settings: KeyboardSettings = KeyboardSettings()) {
        self.layout = layout
        self.settings = settings
    }

    private enum CodingKeys: String, CodingKey { case version, layout, settings }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        layout = try container.decode(KeyboardLayout.self, forKey: .layout)
        settings = try container.decodeIfPresent(KeyboardSettings.self, forKey: .settings) ?? KeyboardSettings()
    }

    static var `default`: KeyboardConfiguration { KeyboardConfiguration(layout: .default) }

    func jsonString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    static func fromJSON(_ string: String) throws -> KeyboardConfiguration {
        try JSONDecoder().decode(KeyboardConfiguration.self, from: Data(string.utf8))
    }
}
