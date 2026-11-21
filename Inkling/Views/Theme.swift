import SwiftUI
import UIKit

/// Paper and ink.
enum Theme {
    static let paper = Color(light: 0xF6F2EA, dark: 0x161412)
    static let card = Color(light: 0xFFFDF8, dark: 0x221F1B)
    static let ink = Color(light: 0x23201C, dark: 0xF1ECE3)
    static let secondary = Color(light: 0x6E665C, dark: 0xA39A8D)
    static let rule = Color(light: 0xE4DDD1, dark: 0x35302A)
    static let onAccent = Color(light: 0xFFFDF8, dark: 0x161412)
    /// Ink blue.
    static let accent = Color(light: 0x334F73, dark: 0xA3BAD9)

    /// The serif voice for prompts and headings.
    static func serif(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif, weight: weight)
    }

    /// A serif numeral at a fixed size, for the streak.
    static func numeral(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .serif)
    }

    /// The plaque voice: small, wide capitals.
    static func caps(_ style: Font.TextStyle = .caption2) -> Font {
        .system(style, weight: .semibold).width(.expanded)
    }

    static func applyNavigationAppearance() {
        let ink = UIColor(Theme.ink)
        let serif = UIFont.systemFont(ofSize: 17, weight: .semibold).withDesign(.serif)
        let large = UIFont.systemFont(ofSize: 34, weight: .semibold).withDesign(.serif)
        let title: [NSAttributedString.Key: Any] = [.foregroundColor: ink, .font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: serif)]
        let largeTitle: [NSAttributedString.Key: Any] = [.foregroundColor: ink, .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large)]
        // Only the title's voice is set; the bar itself stays the system's, so it is glass where the system has glass.
        UINavigationBar.appearance().titleTextAttributes = title
        UINavigationBar.appearance().largeTitleTextAttributes = largeTitle
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

    init(_ rgb: SIMD3<Double>) {
        self.init(red: rgb.x, green: rgb.y, blue: rgb.z)
    }
}

extension View {
    /// Glass where the system has it, a thin material before that.
    @ViewBuilder
    func glass(in shape: some Shape = Capsule(), interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }

    /// Small wide capitals.
    func plaque(_ style: Font.TextStyle = .caption2) -> some View {
        font(Theme.caps(style)).textCase(.uppercase).kerning(1.1)
    }
}

/// A button that sinks a little under the finger.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}
