import CoreText
import Foundation

enum AppFontRegistrar {
    private static let bundledFontFiles = [
        "DMSans-Variable",
        "Syne-Variable"
    ]

    static func registerBundledFonts() {
        for fileName in bundledFontFiles {
            guard let url = Bundle.main.url(forResource: fileName, withExtension: "ttf") else {
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
