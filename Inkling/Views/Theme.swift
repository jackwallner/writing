import SwiftUI
import UIKit

/// Paper and ink.
enum Theme {
    static let paper = Color(light: 0xF6F2EA, dark: 0x1B1916)
    static let card = Color(light: 0xFFFDF8, dark: 0x26231F)
    static let ink = Color(light: 0x23201C, dark: 0xEFEAE1)
    static let secondary = Color(light: 0x6E665C, dark: 0xA39A8D)
    static let rule = Color(light: 0xE4DDD1, dark: 0x3A352F)
    static let onAccent = Color(light: 0xFFFDF8, dark: 0x1B1916)

    /// The serif voice for prompts and headings.
    static func serif(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif, weight: weight)
    }

    static func applyNavigationAppearance() {
        let ink = UIColor(Theme.ink)
        let serif = UIFont.systemFont(ofSize: 17, weight: .semibold).withDesign(.serif)
        let large = UIFont.systemFont(ofSize: 34, weight: .semibold).withDesign(.serif)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(Theme.paper)
        appearance.titleTextAttributes = [.foregroundColor: ink, .font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: serif)]
        appearance.largeTitleTextAttributes = [.foregroundColor: ink, .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large)]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}

private extension UIFont {
    func withDesign(_ design: UIFontDescriptor.SystemDesign) -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(design) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// Loads bundled artwork, downsampled to the size it is drawn at, and keeps it.
@MainActor
enum Art {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(_ name: String) -> UIImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "heic", subdirectory: "Art")
            ?? Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "Art"),
            let image = UIImage(contentsOfFile: url.path) else { return nil }
        let prepared = image.preparingForDisplay() ?? image
        cache.setObject(prepared, forKey: name as NSString)
        return prepared
    }
}

/// An artwork filling its frame, with paper showing while it loads.
struct ArtView: View {
    let name: String
    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(Theme.rule)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .clipped()
            .task(id: name) {
                if image == nil { image = Art.image(name) }
            }
            .accessibilityHidden(true)
    }
}
