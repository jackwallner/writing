import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// A piece of writing set under its painting, as a picture to send to someone.
struct ShareCard: Transferable {
    let prompt: Prompt
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            try await card.png()
        }
        .suggestedFileName("Inkling")
    }

    @MainActor
    func png() throws -> Data {
        let renderer = ImageRenderer(content: ShareCardView(prompt: prompt, text: text, art: Art.decode(prompt.art)))
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else { throw CocoaError(.fileWriteUnknown) }
        return data
    }
}

/// 360 by 450 points: the painting, then the words on paper. Always light, like a printed card.
struct ShareCardView: View {
    let prompt: Prompt
    let text: String
    let art: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(red: 0.89, green: 0.87, blue: 0.82)
                .overlay {
                    if let art { Image(uiImage: art).resizable().scaledToFill() }
                }
                .frame(width: 360, height: 216)
                .clipped()
            VStack(alignment: .leading, spacing: 0) {
                Text(prompt.text)
                    .font(.system(size: 11.5, design: .serif))
                    .italic()
                    .foregroundStyle(Color(red: 0.43, green: 0.40, blue: 0.36))
                    .lineLimit(3)
                Text(text)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(Color(red: 0.14, green: 0.13, blue: 0.11))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 12)
                HStack(alignment: .firstTextBaseline) {
                    Text("Inkling")
                        .font(.system(size: 9, weight: .semibold).width(.expanded))
                        .textCase(.uppercase)
                        .kerning(1.6)
                    Spacer(minLength: 12)
                    Text(prompt.maker)
                        .font(.system(size: 8, weight: .medium).width(.expanded))
                        .textCase(.uppercase)
                        .kerning(1)
                        .lineLimit(1)
                }
                .foregroundStyle(Color(red: 0.43, green: 0.40, blue: 0.36))
                .padding(.top, 10)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 18)
            .frame(width: 360, height: 234, alignment: .topLeading)
        }
        .frame(width: 360, height: 450)
        .background(Color(red: 0.965, green: 0.949, blue: 0.918))
        .environment(\.colorScheme, .light)
    }
}
