import WidgetKit
import OSLog

private let logger = Logger(subsystem: "com.tahoma-macos-app", category: "BlindTimeline")

struct BlindTimelineProvider: AppIntentTimelineProvider {

    /// Interval between pre-scheduled entries while in transit.
    private static let entryInterval = 1.0

    // MARK: - Placeholder / Snapshot

    func placeholder(in context: Context) -> BlindEntry {
        .placeholder
    }

    func snapshot(for configuration: SelectBlindIntent, in context: Context) async -> BlindEntry {
        logger.error("[snapshot] isPreview=\(context.isPreview, privacy: .public)")

        if context.isPreview { return .placeholder }

        guard let device = configuration.device else {
            return .notConfigured
        }

        let cached = BlindState.fromCache(forDevice: device.id)
        let pending = PendingCommand.load(forDevice: device.id)

        return BlindEntry(
            date: .now,
            closure: cached.closure,
            openClosed: cached.openClosed,
            isMoving: pending != nil,
            isReachable: true,
            isConfigured: true,
            deviceURL: device.id,
            deviceLabel: device.label,
            iconType: device.iconType,
            favorites: device.favorites
        )
    }

    // MARK: - Timeline

    func timeline(for configuration: SelectBlindIntent, in context: Context) async -> Timeline<BlindEntry> {
        logger.error("[timeline] ===== START ===== device=\(configuration.device?.label ?? "nil", privacy: .public)")

        guard let device = configuration.device else {
            logger.error("[timeline] no device configured")
            return Timeline(entries: [.notConfigured], policy: .never)
        }

        let deviceURL = device.id

        // 1. Read shared state written by intents.
        let pending = PendingCommand.load(forDevice: deviceURL)
        let pendingAge = pending.map { Date().timeIntervalSince1970 - $0.sentAt } ?? .infinity
        let cachedState = BlindState.fromCache(forDevice: deviceURL)
        let cacheAge = BlindState.cacheAge(forDevice: deviceURL)
        logger.error("[timeline] pending: \(pending.map { "target=\($0.targetClosure), start=\($0.startClosure), age=\(String(format: "%.1f", pendingAge))s" } ?? "none", privacy: .public)")
        logger.error("[timeline] cache: closure=\(cachedState.closure, privacy: .public), age=\(String(format: "%.1f", cacheAge), privacy: .public)s")

        // 2a. OPTIMISTIC MOVE: pending is fresh (< 2s) — intent just fired, skip API.
        if let pending = pending, pendingAge < 2.0 {
            let totalDistance = abs(pending.targetClosure - pending.startClosure)
            if totalDistance > 0 {
                let totalSeconds = Double(totalDistance) * device.effectiveSecondsPerPercent
                let openClosed = pending.startClosure < pending.targetClosure ? "closed" : "open"

                let entries = buildTransitEntries(
                    device: device,
                    fromClosure: pending.startClosure,
                    targetClosure: pending.targetClosure,
                    totalSeconds: totalSeconds,
                    openClosed: openClosed
                )

                logger.error("[timeline] OPTIMISTIC MOVE target=\(pending.targetClosure, privacy: .public), start=\(pending.startClosure, privacy: .public), dist=\(totalDistance, privacy: .public) — \(entries.count, privacy: .public) entries over \(String(format: "%.1f", totalSeconds), privacy: .public)s at \(String(format: "%.3f", device.effectiveSecondsPerPercent), privacy: .public)s/%")
                logger.error("[timeline] ===== END ===== entries=\(entries.count, privacy: .public)")

                return Timeline(
                    entries: entries,
                    policy: .after(Date.now.addingTimeInterval(totalSeconds + 3))
                )
            }
        }

        // 2b. OPTIMISTIC IDLE: no pending AND cache is very fresh — stop/arrive intent just wrote it, skip API.
        if pending == nil && cacheAge < 2.0 && cachedState.closure >= 0 {
            let entry = makeEntry(device: device, state: cachedState, isMoving: false)
            logger.error("[timeline] OPTIMISTIC IDLE at \(cachedState.closure, privacy: .public) — skip API, policy=.atEnd")
            logger.error("[timeline] ===== END ===== closure=\(entry.closure, privacy: .public), isMoving=false")
            return Timeline(entries: [entry], policy: .atEnd)
        }

        // 3. VERIFIED PATH: pending is older or absent — fetch real state from API.
        guard let client = TaHomaClient.fromKeychain() else {
            logger.error("[timeline] no credentials")
            return Timeline(entries: [.notConfigured], policy: .never)
        }

        do {
            let states = try await client.getDeviceState(deviceURL: deviceURL)
            let apiState = BlindState.from(states: states)
            logger.error("[timeline] API: closure=\(apiState.closure, privacy: .public), openClosed=\(apiState.openClosed, privacy: .public)")

            apiState.cacheToDefaults(forDevice: deviceURL)

            if let pending = pending {
                let distance = abs(apiState.closure - pending.targetClosure)
                if distance <= PendingCommand.arrivalTolerance {
                    PendingCommand.clear(forDevice: deviceURL)

                    // Auto-calibrate speed from observed movement
                    let moved = abs(apiState.closure - pending.startClosure)
                    if moved >= 10 {
                        let observed = pending.observedSpeed(currentClosure: apiState.closure)
                        let isRealMeasurement = moved >= 3 && (Date().timeIntervalSince1970 - pending.sentAt) > 0.5
                        if isRealMeasurement {
                            var updatedDevice = device
                            if let existing = device.secondsPerPercent {
                                updatedDevice.secondsPerPercent = existing * 0.7 + observed * 0.3
                            } else {
                                updatedDevice.secondsPerPercent = observed
                            }
                            DeviceStore.addOrUpdate(updatedDevice)
                            let savedSpeed = updatedDevice.secondsPerPercent!
                            logger.error("[timeline] AUTO-CALIBRATE: observed \(String(format: "%.3f", observed), privacy: .public)s/%, saved \(String(format: "%.3f", savedSpeed), privacy: .public)s/% (moved \(moved, privacy: .public)%)")
                        }
                    }

                    let entry = makeEntry(device: device, state: apiState, isMoving: false)
                    logger.error("[timeline] ARRIVED at target \(pending.targetClosure, privacy: .public) (api=\(apiState.closure, privacy: .public), dist=\(distance, privacy: .public)) — idle")
                    logger.error("[timeline] ===== END ===== closure=\(entry.closure, privacy: .public), isMoving=false")
                    return Timeline(entries: [entry], policy: .atEnd)

                } else if cachedState.closure >= 0 && cachedState.closure == apiState.closure && cacheAge >= 4 {
                    PendingCommand.clear(forDevice: deviceURL)
                    let entry = makeEntry(device: device, state: apiState, isMoving: false)
                    logger.error("[timeline] STOPPED at intermediate \(apiState.closure, privacy: .public) (target was \(pending.targetClosure, privacy: .public), unchanged for \(String(format: "%.1f", cacheAge), privacy: .public)s) — idle")
                    logger.error("[timeline] ===== END ===== closure=\(entry.closure, privacy: .public), isMoving=false")
                    return Timeline(entries: [entry], policy: .atEnd)

                } else {
                    let speed = pending.observedSpeed(currentClosure: apiState.closure)
                    let totalSeconds = Double(distance) * speed

                    let entries = buildTransitEntries(
                        device: device,
                        fromClosure: apiState.closure,
                        targetClosure: pending.targetClosure,
                        totalSeconds: totalSeconds,
                        openClosed: apiState.openClosed
                    )

                    logger.error("[timeline] IN TRANSIT target=\(pending.targetClosure, privacy: .public), api=\(apiState.closure, privacy: .public), dist=\(distance, privacy: .public), speed=\(String(format: "%.2f", speed), privacy: .public)s/% (start=\(pending.startClosure, privacy: .public)) — \(entries.count, privacy: .public) entries over \(String(format: "%.1f", totalSeconds), privacy: .public)s")
                    logger.error("[timeline] ===== END ===== entries=\(entries.count, privacy: .public)")

                    return Timeline(
                        entries: entries,
                        policy: .after(Date.now.addingTimeInterval(totalSeconds + 3))
                    )
                }
            } else if apiState.isMoving {
                let entry = makeEntry(device: device, state: apiState, isMoving: true)
                logger.error("[timeline] API reports moving — polling 5s")
                logger.error("[timeline] ===== END ===== closure=\(entry.closure, privacy: .public), isMoving=true")
                return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(5)))
            } else {
                let entry = makeEntry(device: device, state: apiState, isMoving: false)
                logger.error("[timeline] IDLE at \(apiState.closure, privacy: .public) — policy=.atEnd")
                logger.error("[timeline] ===== END ===== closure=\(entry.closure, privacy: .public), isMoving=false")
                return Timeline(entries: [entry], policy: .atEnd)
            }
        } catch {
            logger.error("[timeline] API FAILED: \(error.localizedDescription, privacy: .public)")
            let cached = BlindState.fromCache(forDevice: deviceURL)
            let entry = makeEntry(device: device, state: cached, isMoving: pending != nil, isReachable: false)
            logger.error("[timeline] ===== END (error) ===== using cache, policy=.atEnd")
            return Timeline(entries: [entry], policy: .atEnd)
        }
    }

    // MARK: - Transit Entries

    /// Builds a series of entries that interpolate the blind position from
    /// `fromClosure` to `targetClosure` over `totalSeconds`.
    /// Each intermediate entry shows `isMoving: true` with the estimated position.
    /// The final entry shows `isMoving: false` at the target position.
    private func buildTransitEntries(
        device: BlindDevice,
        fromClosure: Int,
        targetClosure: Int,
        totalSeconds: Double,
        openClosed: String
    ) -> [BlindEntry] {
        let distance = abs(targetClosure - fromClosure)
        let direction: Double = targetClosure > fromClosure ? 1.0 : -1.0
        let interval = Self.entryInterval

        let speed = distance > 0 ? totalSeconds / Double(distance) : 0
        logger.error("[buildTransit] from=\(fromClosure, privacy: .public) → target=\(targetClosure, privacy: .public), dist=\(distance, privacy: .public), totalTime=\(String(format: "%.2f", totalSeconds), privacy: .public)s, interval=\(String(format: "%.1f", interval), privacy: .public)s, speed=\(String(format: "%.3f", speed), privacy: .public)s/%")

        var entries: [BlindEntry] = []
        var t = 0.0

        while t < totalSeconds {
            let progress = t / totalSeconds
            let estimated = Int(round(Double(fromClosure) + Double(distance) * direction * progress))
            let oc = estimated == 0 ? "open" : (estimated >= 100 ? "closed" : openClosed)

            entries.append(makeEntry(
                device: device,
                state: BlindState(closure: estimated, openClosed: oc, isMoving: false),
                isMoving: true,
                date: Date.now.addingTimeInterval(t)
            ))
            t += interval
        }

        // Final entry: arrived at target, idle.
        let finalOC = targetClosure == 0 ? "open" : (targetClosure >= 100 ? "closed" : openClosed)
        entries.append(makeEntry(
            device: device,
            state: BlindState(closure: targetClosure, openClosed: finalOC, isMoving: false),
            isMoving: false,
            date: Date.now.addingTimeInterval(totalSeconds)
        ))

        logger.error("[buildTransit] built \(entries.count, privacy: .public) entries: first=\(fromClosure, privacy: .public)@+0s (moving), last=\(targetClosure, privacy: .public)@+\(String(format: "%.2f", totalSeconds), privacy: .public)s (idle)")

        return entries
    }

    // MARK: - Helpers

    private func makeEntry(
        device: BlindDevice,
        state: BlindState,
        isMoving: Bool,
        isReachable: Bool = true,
        date: Date = .now
    ) -> BlindEntry {
        BlindEntry(
            date: date,
            closure: state.closure,
            openClosed: state.openClosed,
            isMoving: isMoving,
            isReachable: isReachable,
            isConfigured: true,
            deviceURL: device.id,
            deviceLabel: device.label,
            iconType: device.iconType,
            favorites: device.favorites
        )
    }
}
