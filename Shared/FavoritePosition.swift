import Foundation

struct FavoritePosition: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var closurePercentage: Int  // 0=open, 100=closed
    var sfSymbol: String        // e.g. "sun.max.fill"
}

enum FavoriteSymbols {
    static let all: [(symbol: String, label: String)] = [
        ("sun.max.fill", "Day"), ("moon.fill", "Night"),
        ("bed.double.fill", "Sleep"), ("cup.and.saucer.fill", "Morning"),
        ("tv.fill", "Movie"), ("eye.slash.fill", "Privacy"),
        ("leaf.fill", "Nature"), ("cloud.sun.fill", "Cloudy"),
        ("star.fill", "Star"), ("heart.fill", "Heart"),
        ("bolt.fill", "Quick"), ("house.fill", "Home"),
    ]
}
