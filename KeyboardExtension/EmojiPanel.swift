import SwiftUI

/// Panel sencillo de emojis que se abre con la acción "Emojis".
struct EmojiPanel: View {
    @ObservedObject var state: KeyboardState
    let perform: (KeyAction) -> Void

    private let columns = [GridItem(.adaptive(minimum: 40), spacing: 2)]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Self.emojis.indices, id: \.self) { index in
                        let emoji = Self.emojis[index]
                        Button {
                            state.playKeyFeedback()
                            perform(.character(emoji))
                        } label: {
                            Text(emoji)
                                .font(.system(size: 30))
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            KeyboardGrid(rows: [Self.bottomRow], rowHeight: state.rowHeight) { key in
                Button {
                    handle(key)
                } label: {
                    KeyCapView(key: key, rowHeight: state.rowHeight)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func handle(_ key: KeyDefinition) {
        state.playKeyFeedback()
        if key.id == Self.closeKey.id {
            state.showingEmoji = false
        } else {
            perform(key.primary)
        }
    }

    private static let closeKey = KeyDefinition(primary: KeyAction(.none), width: 1.5, label: "ABC")
    private static let bottomRow = KeyRow(keys: [
        closeKey,
        KeyDefinition(primary: KeyAction(.space), width: 6),
        KeyDefinition(primary: KeyAction(.backspace), width: 1.5),
    ])

    static let emojis: [String] = {
        let all = """
        😀😃😄😁😆😅😂🤣🥲☺️😊😇🙂🙃😉😌😍🥰😘😗😙😚😋😛😝😜🤪🤨🧐🤓😎🥸🤩🥳😏😒😞😔😟😕🙁☹️😣😖😫😩🥺😢😭😤😠😡🤬🤯😳🥵🥶😱😨😰😥😓🤗🤔🫣🤭🫢🤫🤥😶😐😑😬🙄😯😦😧😮😲🥱😴🤤😪😵🤐🥴🤢🤮🤧😷🤒🤕🤑🤠😈👿👹👺🤡💩👻💀👽🤖🎃😺😸😹😻😼😽🙀😿😾\
        👋🤚🖐✋🖖👌🤌🤏✌️🤞🫰🤟🤘🤙👈👉👆🖕👇☝️👍👎✊👊🤛🤜👏🙌🫶👐🤲🤝🙏✍️💪🧠👀👁👅👄💋\
        ❤️🧡💛💚💙💜🖤🤍🤎💔❣️💕💞💓💗💖💘💝💟✨⭐️🌟💫🔥💥💯✅❌⚠️❓❗️💤🎉🎊🎁🎈🎂🍰☕️🍺🍻🥂🍷🍕🍔🌮🍣🍎🍓🍌🍉🥑🌶\
        🐶🐱🐭🐹🐰🦊🐻🐼🐨🐯🦁🐮🐷🐸🐵🐔🐧🐦🐤🦆🦅🦉🐴🦄🐝🦋🐌🐞🐢🐍🐙🐠🐬🐳🌵🌲🌴🌱🌿🍀🌸🌹🌻🌞🌝🌙🌈☀️☁️🌧⛄️❄️🌊\
        ⚽️🏀🏈⚾️🎾🏐🎮🎲🎸🎧🎤🎬📷📱💻⌨️💡📚✏️📌📎🔑🔒🏠🚗✈️🚀⏰📅💰💳🇲🇽🇪🇸🇦🇷🇨🇴🇨🇱🇵🇪🇺🇸
        """
        return all.filter { !$0.isNewline }.map { String($0) }
    }()
}
