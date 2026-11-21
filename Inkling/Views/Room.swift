import SwiftUI

/// An artwork in its frame: filling it, or shown whole.
struct ArtView: View {
    let name: String
    var size: Art.Size = .card
    var whole = false
    var alignment = Alignment.center
    @State private var image: UIImage?

    init(name: String, size: Art.Size = .card, whole: Bool = false, alignment: Alignment = .center) {
        self.name = name
        self.size = size
        self.whole = whole
        self.alignment = alignment
        _image = State(initialValue: Art.cached(name, size))
    }

    var body: some View {
        Color.clear
            .overlay(alignment: alignment) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: whole ? .fit : .fill)
                        .transition(.opacity)
                } else if !whole {
                    Theme.rule
                }
            }
            .clipped()
            .task(id: name) {
                let loaded = await Art.image(name, size)
                if loaded != image { withAnimation(.easeOut(duration: 0.25)) { image = loaded } }
            }
            .accessibilityHidden(true)
    }
}

/// The room a painting hangs in: a slow field of the painting's own colors.
struct RoomBackdrop: View {
    let palette: Palette
    var paused = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var from = Palette.neutral
    @State private var to = Palette.neutral
    @State private var changed = Date.distantPast

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused || reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let progress = reduceMotion ? 1 : min(1, max(0, context.date.timeIntervalSince(changed) / 0.9))
            let eased = progress * progress * (3 - 2 * progress)
            MeshGradient(
                width: 3, height: 3,
                points: points(reduceMotion ? 0 : time),
                colors: from.mixed(with: to, eased).room(dark: scheme == .dark).map { Color($0) },
                smoothsColors: true
            )
        }
        .onAppear { from = palette; to = palette }
        .onChange(of: palette) { _, new in
            let progress = min(1, max(0, Date.now.timeIntervalSince(changed) / 0.9))
            from = from.mixed(with: to, progress)
            to = new
            changed = .now
        }
        .accessibilityHidden(true)
    }

    /// The corners stay put; the edges and the middle drift.
    private func points(_ time: Double) -> [SIMD2<Float>] {
        func drift(_ speed: Double, _ phase: Double) -> Float { Float(sin(time * speed + phase) * 0.11) }
        return [
            [0, 0], [0.5 + drift(0.23, 0), 0], [1, 0],
            [0, 0.5 + drift(0.19, 1.7)], [0.5 + drift(0.17, 3.1), 0.5 + drift(0.21, 0.6)], [1, 0.5 + drift(0.15, 4.2)],
            [0, 1], [0.5 + drift(0.2, 2.4), 1], [1, 1],
        ]
    }
}
