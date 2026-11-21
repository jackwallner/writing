import SwiftUI
import WidgetKit

struct PromptEntry: TimelineEntry {
    let date: Date
    let prompt: Prompt?
}

/// Each day's three paintings take the morning, the afternoon and the evening.
struct PromptProvider: TimelineProvider {
    private static let hours = [0, 12, 17]

    func placeholder(in context: Context) -> PromptEntry { entry(at: .now) }

    func getSnapshot(in context: Context, completion: @escaping (PromptEntry) -> Void) {
        completion(entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PromptEntry>) -> Void) {
        let now = Date.now
        var entries = [entry(at: now)]
        for offset in 0..<3 {
            let day = Days.adding(offset, to: now)
            for hour in Self.hours {
                if let date = Days.calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day), date > now {
                    entries.append(entry(at: date))
                }
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> PromptEntry {
        let options = PromptLibrary.bundled.options(for: date)
        let hour = Days.calendar.component(.hour, from: date)
        let index = Self.hours.lastIndex { $0 <= hour } ?? 0
        return PromptEntry(date: date, prompt: options.indices.contains(index) ? options[index] : options.first)
    }
}

struct PromptWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PromptEntry

    private static let paper = Color(red: 0.965, green: 0.949, blue: 0.918)
    private static let ink = Color(red: 0.14, green: 0.13, blue: 0.11)
    private static let soft = Color(red: 0.43, green: 0.40, blue: 0.36)

    private var art: UIImage? { entry.prompt.flatMap { Art.decode($0.art, .widget) } }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: lockScreen
            case .systemSmall: Color.clear
            case .systemMedium: medium
            default: large
            }
        }
        .containerBackground(for: .widget) {
            if family == .systemSmall { painting } else { Self.paper }
        }
        .widgetURL(entry.prompt.flatMap { URL(string: "inkling://prompt/\($0.id)") })
    }

    @ViewBuilder
    private var painting: some View {
        if let art {
            Image(uiImage: art).resizable().scaledToFill()
        } else {
            Self.paper
        }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.prompt?.maker ?? "")
                .font(.system(size: 8.5, weight: .semibold).width(.expanded))
                .textCase(.uppercase)
                .kerning(1)
                .foregroundStyle(Self.soft)
                .lineLimit(1)
            Text(entry.prompt?.text ?? "")
                .font(.system(family == .systemLarge ? .body : .footnote, design: .serif))
                .foregroundStyle(Self.ink)
                .lineSpacing(2)
                .minimumScaleFactor(0.8)
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            Color.clear
                .overlay { painting }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .aspectRatio(0.82, contentMode: .fit)
            words.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 14) {
            Color.clear
                .overlay { painting }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            words.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var lockScreen: some View {
        Text(entry.prompt?.text ?? "")
            .font(.system(.caption, design: .serif))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

@main
struct InklingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayPrompt", provider: PromptProvider()) { entry in
            PromptWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Painting")
        .description("A painting and its prompt, three a day.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}
