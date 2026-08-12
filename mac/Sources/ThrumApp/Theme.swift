import SwiftUI
import CoreText

/// The same six colours and three faces as the landing page, so the app and the
/// site are recognisably one product.
enum Theme {
    static let tape       = Color(hex: 0xF7F6E9)
    static let ink        = Color(hex: 0x16150F)
    static let graphite   = Color(hex: 0x6B6A5C)
    /// Full strength on an actively firing pulse and the playhead. Nowhere else.
    static let signal     = Color(hex: 0x1F3BE0)
    static let signalWash = Color(hex: 0xDCE0FC)
    static let rule       = Color(hex: 0xE2E1D0)

    /// Family names discovered at registration rather than hardcoded — a font that
    /// fails to register falls back to the system face instead of rendering nothing.
    private static var families: [String: String] = [:]

    static func registerFonts() {
        let names = ["InstrumentSerif-Regular", "InstrumentSerif-Italic",
                     "Geist-400", "Geist-500", "GeistMono-400"]
        for name in names {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
               let first = descriptors.first,
               let family = CTFontDescriptorCopyAttribute(first, kCTFontFamilyNameAttribute) as? String {
                families[name] = family
            }
        }
    }

    private static func family(_ key: String) -> String? { families[key] }

    /// Display face. Only earns its keep at 56pt and up.
    ///
    /// Both faces register under the family "Instrument Serif", so the italic has to
    /// be asked for by trait — naming the file doesn't select it.
    static func display(_ size: CGFloat, italic: Bool = false) -> Font {
        guard let name = family("InstrumentSerif-Regular") else {
            let base = Font.system(size: size, design: .serif)
            return italic ? base.italic() : base
        }
        let font = Font.custom(name, size: size)
        return italic ? font.italic() : font
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let heavier: Set<Font.Weight> = [.medium, .semibold, .bold, .heavy, .black]
        let key = heavier.contains(weight) ? "Geist-500" : "Geist-400"
        guard let name = family(key) else { return .system(size: size, weight: weight) }
        return .custom(name, size: size).weight(weight)
    }

    /// Timings, WPM readouts, morse strings — anything you'd want to compare by column.
    static func mono(_ size: CGFloat) -> Font {
        guard let name = family("GeistMono-400") else { return .system(size: size, design: .monospaced) }
        return .custom(name, size: size)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

