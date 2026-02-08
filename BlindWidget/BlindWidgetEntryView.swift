import SwiftUI
import WidgetKit

struct BlindWidgetEntryView: View {
    var entry: BlindEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: - Computed Properties

    private var deviceURL: String { entry.deviceURL ?? "" }

    private var closureFraction: CGFloat {
        entry.closure >= 0 ? CGFloat(entry.closure) / 100.0 : 0.5
    }

    private var stateColor: Color {
        BlindColors.stateColor(closure: entry.closure, isMoving: entry.isMoving)
    }

    private var stateLabel: String {
        if entry.isMoving { return "Moving..." }
        switch entry.closure {
        case 0: return "Open"
        case 100: return "Closed"
        case let c where c > 0: return "Open \(100 - c)%"
        default: return entry.openClosed.capitalized
        }
    }

    private var isDaytime: Bool {
        let hour = Calendar.current.component(.hour, from: entry.date)
        return hour >= 7 && hour < 20
    }

    private var starPhase: CGFloat {
        CGFloat(entry.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 5.0) / 5.0)
    }

    // MARK: - Small Widget

    private var smallView: some View {
        VStack(spacing: Spacing.sm) {
            if !entry.isConfigured {
                notConfiguredView
            } else {
                BlindIconView(
                    iconType: entry.iconType,
                    closureFraction: closureFraction,
                    tintColor: stateColor,
                    size: 48,
                    isDaytime: isDaytime,
                    starPhase: starPhase
                )
                .widgetAccentable()

                Text(stateLabel)
                    .font(AppTypography.widgetBody)
                    .foregroundStyle(stateColor)

                if !entry.isReachable {
                    Label("Offline", systemImage: "wifi.slash")
                        .font(AppTypography.widgetCaption2)
                        .foregroundStyle(.red)
                }

                if entry.isMoving {
                    Button(intent: StopBlindIntent(deviceURL: deviceURL)) {
                        Image(systemName: "stop.fill")
                            .font(.caption.bold())
                            .frame(width: 28, height: 22)
                            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: Spacing.md) {
                        Button(intent: OpenBlindIntent(deviceURL: deviceURL)) {
                            Image(systemName: "chevron.up")
                                .font(.caption.bold())
                                .frame(width: 28, height: 22)
                                .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)

                        Button(intent: CloseBlindIntent(deviceURL: deviceURL)) {
                            Image(systemName: "chevron.down")
                                .font(.caption.bold())
                                .frame(width: 28, height: 22)
                                .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Medium Widget

    private var mediumView: some View {
        HStack(spacing: Spacing.lg) {
            if !entry.isConfigured {
                notConfiguredView
            } else {
                VStack(spacing: Spacing.sm) {
                    if let label = entry.deviceLabel {
                        Text(label)
                            .font(AppTypography.widgetCaption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    BlindIconView(
                        iconType: entry.iconType,
                        closureFraction: closureFraction,
                        tintColor: stateColor,
                        size: 56,
                        isDaytime: isDaytime,
                        starPhase: starPhase
                    )

                    Text(stateLabel)
                        .font(AppTypography.widgetTitle)
                        .foregroundStyle(stateColor)

                    if entry.closure >= 0 {
                        percentageBar
                    }

                    if !entry.isReachable {
                        Label("Offline", systemImage: "wifi.slash")
                            .font(AppTypography.widgetCaption2)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: Spacing.sm) {
                    if entry.isMoving {
                        Spacer()
                        Button(intent: StopBlindIntent(deviceURL: deviceURL)) {
                            Label("Stop", systemImage: "stop.fill")
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundStyle(.red)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.red.opacity(0.15), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    } else {
                        Button(intent: OpenBlindIntent(deviceURL: deviceURL)) {
                            Label("Open", systemImage: "chevron.up")
                                .font(.system(.body, design: .rounded))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BlindColors.open)

                        Button(intent: CloseBlindIntent(deviceURL: deviceURL)) {
                            Label("Close", systemImage: "chevron.down")
                                .font(.system(.body, design: .rounded))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BlindColors.closed)

                        if !entry.favorites.isEmpty {
                            HStack(spacing: Spacing.xs) {
                                ForEach(entry.favorites) { fav in
                                    Button(intent: SetPositionIntent(deviceURL: deviceURL, closurePercentage: fav.closurePercentage)) {
                                        VStack(spacing: 2) {
                                            Image(systemName: fav.sfSymbol)
                                                .font(.caption2)
                                            Text("\(100 - fav.closurePercentage)%")
                                                .font(.system(.caption2, design: .rounded))
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Shared Components

    private var percentageBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.fill.quaternary)
                Capsule()
                    .fill(stateColor)
                    .frame(width: geo.size.width * (1.0 - closureFraction))
            }
        }
        .frame(height: 4)
    }

    private var notConfiguredView: some View {
        VStack(spacing: Spacing.sm) {
            BlindIconView(
                iconType: .estore,
                closureFraction: 0.5,
                tintColor: .secondary,
                size: 40,
                isDaytime: isDaytime,
                starPhase: starPhase
            )
            Text("Select a blind")
                .font(AppTypography.widgetBody)
                .foregroundStyle(.secondary)
            Text("Edit this widget")
                .font(AppTypography.widgetCaption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
