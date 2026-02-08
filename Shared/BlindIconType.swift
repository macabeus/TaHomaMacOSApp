import Foundation

enum BlindIconType: String, Codable, CaseIterable, Hashable, Sendable {
    case estore
    case verticalBlind
    case skylightBlind

    var displayName: String {
        switch self {
        case .estore: return "Roller Shutter"
        case .verticalBlind: return "Vertical Blind"
        case .skylightBlind: return "Skylight Blind"
        }
    }

    var displayDescription: String {
        switch self {
        case .estore: return "Exterior roller shutters"
        case .verticalBlind: return "Interior vertical slats"
        case .skylightBlind: return "Angled roof window fabric"
        }
    }
}
