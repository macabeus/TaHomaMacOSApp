import WidgetKit

struct BlindEntry: TimelineEntry {
    let date: Date
    let closure: Int          // 0=open, 100=closed, -1=unknown
    let openClosed: String    // "open" / "closed" / "unknown"
    let isMoving: Bool
    let isReachable: Bool
    let isConfigured: Bool
    let deviceURL: String?
    let deviceLabel: String?
    let iconType: BlindIconType
    let favorites: [FavoritePosition]

    static let placeholder = BlindEntry(
        date: .now,
        closure: 0,
        openClosed: "open",
        isMoving: false,
        isReachable: true,
        isConfigured: true,
        deviceURL: nil,
        deviceLabel: nil,
        iconType: .estore,
        favorites: []
    )

    static let notConfigured = BlindEntry(
        date: .now,
        closure: -1,
        openClosed: "unknown",
        isMoving: false,
        isReachable: false,
        isConfigured: false,
        deviceURL: nil,
        deviceLabel: nil,
        iconType: .estore,
        favorites: []
    )
}
