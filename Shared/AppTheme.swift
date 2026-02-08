import SwiftUI

// MARK: - App Colors (Proxly-inspired dark palette)

enum AppColors {
    static let background = Color(red: 0.08, green: 0.07, blue: 0.14)
    static let cardBackground = Color.white.opacity(0.06)
    static let cardBorder = Color.white.opacity(0.10)
    static let innerCardBackground = Color.white.opacity(0.04)
    static let innerCardBorder = Color.white.opacity(0.07)

    static let accentGradient = LinearGradient(
        colors: [.blue, .indigo],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Blind State Colors

enum BlindColors {
    static let open = Color.green
    static let closed = Color.indigo
    static let partial = Color.blue
    static let moving = Color.orange
    static let unknown = Color.secondary

    static func stateColor(closure: Int, isMoving: Bool) -> Color {
        if isMoving { return moving }
        switch closure {
        case 0: return open
        case 100: return closed
        case let c where c > 0: return partial
        default: return unknown
        }
    }
}

// MARK: - Spacing (8pt grid)

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
}

// MARK: - Typography

enum AppTypography {
    static let widgetTitle = Font.system(.headline, design: .rounded).bold()
    static let widgetBody = Font.system(.body, design: .rounded)
    static let widgetCaption = Font.system(.caption, design: .rounded)
    static let widgetCaption2 = Font.system(.caption2, design: .rounded)

    static let appLargeTitle = Font.system(.largeTitle, design: .rounded).bold()
    static let appTitle = Font.system(.title, design: .rounded).bold()
    static let appTitle2 = Font.system(.title2, design: .rounded).bold()
    static let appHeadline = Font.system(.headline, design: .rounded)
    static let appBody = Font.system(.body, design: .rounded)
    static let appCaption = Font.system(.caption, design: .rounded)
    static let appCaption2 = Font.system(.caption2, design: .rounded)
}

// MARK: - Corner Radius

enum AppCornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
}

// MARK: - Card View Modifiers

extension View {
    func cardStyle() -> some View {
        self
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .fill(AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .stroke(AppColors.cardBorder, lineWidth: 0.5)
            )
    }

    func innerCardStyle() -> some View {
        self
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.small)
                    .fill(AppColors.innerCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.small)
                    .stroke(AppColors.innerCardBorder, lineWidth: 0.5)
            )
    }
}
