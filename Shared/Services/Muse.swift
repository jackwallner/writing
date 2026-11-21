import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// One question from the phone's own language model, to take a piece of writing further.
/// It runs on the device: nothing written leaves it, and it costs nothing to run.
enum Muse {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return SystemLanguageModel.default.isAvailable }
        #endif
        return false
    }

    /// A question about what was written, or nil when the model has nothing to offer.
    static func question(prompt: String, writing: String) async -> String? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable else { return nil }
        let instructions = """
        You are a warm, perceptive writing teacher. A writer is answering a writing prompt about a painting. \
        Ask one short question, grounded in a specific detail they wrote, that invites them to keep writing. \
        Reply with the question only: under 22 words, no preamble, no quotation marks, no advice.
        """
        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(to: "The prompt: \(prompt)\n\nWhat they have written so far:\n\(String(writing.suffix(1800)))")
            return tidy(response.content)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    /// One clean line: no wrapping quotes, no long dashes, nothing after the first line.
    static func tidy(_ raw: String) -> String? {
        let line = raw.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let text = line
            .replacingOccurrences(of: " \u{2014} ", with: ", ")
            .replacingOccurrences(of: "\u{2014}", with: ", ")
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"\u{201C}\u{201D}' ").union(.whitespacesAndNewlines))
        return text.isEmpty ? nil : text
    }
}
