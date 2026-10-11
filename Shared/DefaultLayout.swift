import Foundation

extension KeyboardLayout {
    /// Distribución por defecto: QWERTY en español con un símbolo secundario por tecla.
    static var `default`: KeyboardLayout {
        func row(_ pairs: [(String, String)]) -> [KeyDefinition] {
            pairs.map { KeyDefinition(primary: .character($0.0), secondary: .character($0.1)) }
        }

        let numbers: [KeyDefinition] =
            [KeyDefinition(primary: .character("1"), secondary: KeyAction(.emoji))]
            + row([("2", "\""), ("3", "#"), ("4", "$"), ("5", "%"),
                   ("6", "&"), ("7", "/"), ("8", "("), ("9", ")")])
            + [KeyDefinition(primary: .character("0"), secondary: KeyAction(.paste))]

        let top = row([("q", "_"), ("w", "\\"), ("e", "é"), ("r", "|"), ("t", "<"),
                       ("y", ">"), ("u", "ú"), ("i", "í"), ("o", "ó"), ("p", "•")])

        let middle = row([("a", "á"), ("s", "/"), ("d", ":"), ("f", ";"), ("g", "["),
                          ("h", "]"), ("j", "¡"), ("k", "!"), ("l", "@")])
            + [KeyDefinition(primary: .character("ñ"), secondary: KeyAction(.dictation))]

        let bottom: [KeyDefinition] =
            [KeyDefinition(primary: KeyAction(.shift), width: 1.5)]
            + row([("z", "+"), ("x", "-"), ("c", "*"), ("v", "¿"), ("b", "?"), ("n", ","), ("m", ".")])
            + [KeyDefinition(primary: KeyAction(.backspace), secondary: KeyAction(.deleteWord), width: 1.5)]

        let actions: [KeyDefinition] = [
            KeyDefinition(primary: KeyAction(.dismissKeyboard), width: 2),
            KeyDefinition(primary: KeyAction(.space), width: 6),
            KeyDefinition(primary: KeyAction(.returnKey), width: 2),
        ]

        return KeyboardLayout(
            name: "Leonera",
            rows: [numbers, top, middle, bottom, actions].map { KeyRow(keys: $0) }
        )
    }
}
