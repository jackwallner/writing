import SwiftUI
import UIKit

/// The whole painting on black, to pinch into and look closely.
struct ArtViewer: View {
    let prompt: Prompt
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    init(prompt: Prompt) {
        self.prompt = prompt
        _image = State(initialValue: Art.cached(prompt.art))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image {
                ZoomableImage(image: image)
                    .ignoresSafeArea()
                    .accessibilityLabel(prompt.credit)
                    .accessibilityAddTraits(.isImage)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .glass(in: Circle(), interactive: true)
            }
            .accessibilityLabel("Close")
            .accessibilityIdentifier("viewer.close")
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 5) {
                Text(prompt.title)
                    .font(Theme.serif(.subheadline))
                    .italic()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(prompt.maker)
                    .plaque()
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
            .allowsHitTesting(false)
        }
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .task { if image == nil { image = await Art.image(prompt.art) } }
    }
}

/// A scroll view that zooms: pinch, pan, double tap.
private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 6
        scroll.bouncesZoom = true
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.backgroundColor = .clear
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        view.frame = scroll.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scroll.addSubview(view)
        context.coordinator.imageView = view
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        @objc func doubleTapped(_ gesture: UITapGestureRecognizer) {
            guard let scroll = gesture.view as? UIScrollView, let imageView else { return }
            if scroll.zoomScale > 1.01 {
                scroll.setZoomScale(1, animated: true)
                return
            }
            let point = gesture.location(in: imageView)
            let scale: CGFloat = 3
            let size = CGSize(width: scroll.bounds.width / scale, height: scroll.bounds.height / scale)
            scroll.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), animated: true)
        }
    }
}
