import AppIntents
import WidgetKit

struct SelectBlindIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Blind"
    static var description = IntentDescription("Choose which blind this widget controls.")

    @Parameter(title: "Blind")
    var device: BlindDevice?
}
