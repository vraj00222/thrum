import Foundation

/// Text <-> Morse. Behaviourally identical to `web/lib/morse.ts` — both read the
/// same fixture file, so a divergence fails a test on one side or the other.
public enum MorseCode {

    public static let table: [Character: String] = [
        "A": ".-", "B": "-...", "C": "-.-.", "D": "-..", "E": ".", "F": "..-.",
        "G": "--.", "H": "....", "I": "..", "J": ".---", "K": "-.-", "L": ".-..",
        "M": "--", "N": "-.", "O": "---", "P": ".--.", "Q": "--.-", "R": ".-.",
        "S": "...", "T": "-", "U": "..-", "V": "...-", "W": ".--", "X": "-..-",
        "Y": "-.--", "Z": "--..",
        "0": "-----", "1": ".----", "2": "..---", "3": "...--", "4": "....-",
        "5": ".....", "6": "-....", "7": "--...", "8": "---..", "9": "----.",
        ".": ".-.-.-", ",": "--..--", "?": "..--..", "'": ".----.", "!": "-.-.--",
        "/": "-..-.", "(": "-.--.", ")": "-.--.-", "&": ".-...", ":": "---...",
        ";": "-.-.-.", "=": "-...-", "+": ".-.-.", "-": "-....-", "_": "..--.-",
        "\"": ".-..-.", "$": "...-..-", "@": ".--.-."
    ]

    private static let reverse: [String: Character] = {
        var r = [String: Character]()
        for (char, code) in table { r[code] = char }
        return r
    }()

    /// A run of symbols sent as one character — a letter, or a bracketed prosign.
    struct Unit {
        let code: String
        let source: String
    }

    /// Splits text into sendable units. `<AR>` becomes one unit, so no inter-character
    /// gap lands inside it — that's the whole point of a prosign.
    static func units(in word: String) -> [Unit] {
        var out = [Unit]()
        let chars = Array(word.uppercased())
        var i = 0
        while i < chars.count {
            if chars[i] == "<", let close = chars[i...].firstIndex(of: ">") {
                let inner = String(chars[(i + 1)..<close])
                let code = inner.compactMap { table[$0] }.joined()
                if !code.isEmpty { out.append(Unit(code: code, source: "<\(inner)>")) }
                i = close + 1
                continue
            }
            if let code = table[chars[i]] {
                out.append(Unit(code: code, source: String(chars[i])))
            }
            i += 1
        }
        return out
    }

    public static func tokenize(_ text: String) -> [MorseToken] {
        let words = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var tokens = [MorseToken]()
        for word in words {
            let charUnits = units(in: word)
            guard !charUnits.isEmpty else { continue }
            if !tokens.isEmpty { tokens.append(.wordGap) }
            for (u, unit) in charUnits.enumerated() {
                if u > 0 { tokens.append(.charGap) }
                for (s, symbol) in unit.code.enumerated() {
                    if s > 0 { tokens.append(.intraGap) }
                    tokens.append(symbol == "." ? .dit : .dah)
                }
            }
        }
        return tokens
    }

    public static func encodeToString(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace })
            .map { units(in: String($0)).map(\.code).joined(separator: " ") }
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }

    public static func decode(_ morse: String) -> String {
        morse.split(whereSeparator: { $0.isWhitespace })
            .map { $0 == "/" ? " " : String(reverse[String($0)] ?? "\u{FFFD}") }
            .joined()
            .trimmingCharacters(in: .whitespaces)
    }

    /// Characters we'd silently drop. Drives the inline warning in the composer.
    public static func unsupported(in text: String) -> Set<Character> {
        var out = Set<Character>()
        for char in text.uppercased() where !char.isWhitespace && char != "<" && char != ">" {
            if table[char] == nil { out.insert(char) }
        }
        return out
    }
}
