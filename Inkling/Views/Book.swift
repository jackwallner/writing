import CoreTransferable
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Everything written, set as a small book: a cover, then each piece under its painting.
struct Book: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { _ in
            SentTransferredFile(try await Book.write())
        }
    }

    private static let page = CGRect(x: 0, y: 0, width: 432, height: 648)
    private static let margin: CGFloat = 46
    private static let ink = UIColor(red: 0.14, green: 0.13, blue: 0.11, alpha: 1)
    private static let soft = UIColor(red: 0.43, green: 0.40, blue: 0.36, alpha: 1)
    private static let paper = UIColor(red: 0.965, green: 0.949, blue: 0.918, alpha: 1)

    private static func serif(_ size: CGFloat, italic: Bool = false, weight: UIFont.Weight = .regular) -> UIFont {
        var descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.serif) ?? UIFont.systemFont(ofSize: size).fontDescriptor
        if italic, let slanted = descriptor.withSymbolicTraits(.traitItalic) { descriptor = slanted }
        return UIFont(descriptor: descriptor, size: size)
    }

    private static func caps(_ text: String, size: CGFloat = 7.5) -> NSAttributedString {
        NSAttributedString(string: text.uppercased(), attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: .semibold), .foregroundColor: soft, .kern: 1.4,
        ])
    }

    /// Writes the book to a temporary file and returns it.
    @MainActor
    static func write(journal: Journal = .shared, library: PromptLibrary = .bundled) throws -> URL {
        let entries = journal.entries.filter(\.counts).sorted { ($0.day, $0.created) < ($1.day, $1.created) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Inkling.pdf")
        let width = page.width - margin * 2
        let dates = DateFormatter()
        dates.dateStyle = .long
        let spans = DateIntervalFormatter()
        spans.dateStyle = .long
        spans.timeStyle = .none

        try UIGraphicsPDFRenderer(bounds: page).writePDF(to: url) { context in
            func newPage() {
                context.beginPage()
                paper.setFill()
                context.fill(page)
            }
            @discardableResult
            func draw(_ text: NSAttributedString, at y: CGFloat) -> CGFloat {
                let bounds = text.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil)
                text.draw(with: CGRect(x: margin, y: y, width: width, height: ceil(bounds.height)), options: [.usesLineFragmentOrigin], context: nil)
                return y + ceil(bounds.height)
            }
            func drawArt(_ name: String, in box: CGRect, fill: Bool) -> CGRect {
                guard let image = Art.decode(name) else { return .zero }
                let scale = fill ? max(box.width / image.size.width, box.height / image.size.height) : min(box.width / image.size.width, box.height / image.size.height)
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                let rect = CGRect(x: box.midX - size.width / 2, y: fill ? box.midY - size.height / 2 : box.minY, width: size.width, height: size.height)
                context.cgContext.saveGState()
                context.cgContext.clip(to: box)
                image.draw(in: rect)
                context.cgContext.restoreGState()
                return fill ? box : rect
            }

            // Cover.
            newPage()
            let coverArt = entries.last.flatMap { library.prompt(id: $0.promptID)?.art }
            if let coverArt { _ = drawArt(coverArt, in: CGRect(x: 0, y: 0, width: page.width, height: 400), fill: true) }
            var y: CGFloat = 446
            y = draw(NSAttributedString(string: "Inkling", attributes: [.font: serif(40, weight: .semibold), .foregroundColor: ink]), at: y) + 10
            if let first = entries.first.flatMap({ Days.date($0.day) }), let last = entries.last.flatMap({ Days.date($0.day) }) {
                let span = first == last ? dates.string(from: first) : spans.string(from: first, to: last)
                y = draw(caps(span, size: 8.5), at: y) + 6
            }
            let days = Set(entries.map(\.day)).count
            let words = entries.reduce(0) { $0 + $1.words }
            draw(caps(String(localized: "\(days) days, \(words) words"), size: 8.5), at: y)

            // One piece at a time.
            let body = NSMutableParagraphStyle()
            body.lineSpacing = 4.5
            for entry in entries {
                guard let prompt = library.prompt(id: entry.promptID) else { continue }
                newPage()
                var y = margin
                let art = drawArt(prompt.art, in: CGRect(x: margin, y: y, width: width, height: 230), fill: false)
                y = (art == .zero ? y : art.maxY) + 8
                y = draw(caps(prompt.credit, size: 6.5), at: y) + 22
                if let date = Days.date(entry.day) { y = draw(caps(dates.string(from: date)), at: y) + 8 }
                y = draw(NSAttributedString(string: prompt.text, attributes: [.font: serif(12.5, italic: true), .foregroundColor: soft]), at: y) + 16

                let text = entry.text.isEmpty ? String(localized: "Written elsewhere") : entry.text
                let storage = NSTextStorage(string: text, attributes: [.font: serif(11.5), .foregroundColor: ink, .paragraphStyle: body])
                let layout = NSLayoutManager()
                storage.addLayoutManager(layout)
                var frame = CGRect(x: margin, y: y, width: width, height: page.height - margin - y)
                // The writing runs on over as many pages as it needs.
                for _ in 0..<400 {
                    if frame.height < 40 {
                        newPage()
                        frame = CGRect(x: margin, y: margin, width: width, height: page.height - margin * 2)
                    }
                    let container = NSTextContainer(size: frame.size)
                    container.lineFragmentPadding = 0
                    layout.addTextContainer(container)
                    let range = layout.glyphRange(for: container)
                    layout.drawGlyphs(forGlyphRange: range, at: frame.origin)
                    if range.length == 0 || NSMaxRange(range) >= layout.numberOfGlyphs { break }
                    frame.size.height = 0
                }
            }
        }
        return url
    }
}
