import WidgetKit
import SwiftUI

struct BlindWidget: Widget {
    let kind = SharedConfig.widgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectBlindIntent.self, provider: BlindTimelineProvider()) { entry in
            BlindWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Blind Control")
        .description("Control your TaHoma roller blind.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
