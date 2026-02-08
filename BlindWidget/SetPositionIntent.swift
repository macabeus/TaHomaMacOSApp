import AppIntents
import OSLog
import WidgetKit

private let logger = Logger(subsystem: "com.tahoma-macos-app", category: "SetPositionIntent")

struct SetPositionIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Blind Position"
    static var description = IntentDescription("Sets the roller blind to a specific position.")

    @Parameter(title: "Device URL")
    var deviceURL: String

    @Parameter(title: "Closure Percentage")
    var closurePercentage: Int

    init() {
        self.deviceURL = ""
        self.closurePercentage = 0
    }

    init(deviceURL: String, closurePercentage: Int) {
        self.deviceURL = deviceURL
        self.closurePercentage = closurePercentage
    }

    func perform() async throws -> some IntentResult {
        logger.error("[perform] deviceURL=\(deviceURL, privacy: .public), target=\(closurePercentage, privacy: .public)")
        guard !deviceURL.isEmpty else { return .result() }

        // Optimistic: save state FIRST so the timeline updates instantly.
        let startClosure = BlindState.fromCache(forDevice: deviceURL).closure
        let start = max(0, startClosure)
        let dist = abs(closurePercentage - start)
        let speed = DeviceStore.speedForDevice(deviceURL)
        let predictedTime = Double(dist) * speed
        PendingCommand(targetClosure: closurePercentage, startClosure: start, sentAt: Date().timeIntervalSince1970)
            .save(forDevice: deviceURL)
        BlindState(closure: closurePercentage, openClosed: closurePercentage == 0 ? "open" : "closed", isMoving: true)
            .cacheToDefaults(forDevice: deviceURL)

        // Fire command in background — we expect it to succeed.
        if let client = TaHomaClient.fromKeychain() {
            Task { try? await client.sendCommand(deviceURL: deviceURL, command: "setClosure", parameters: [closurePercentage]) }
        }

        logger.error("[perform] SET saved pending(target=\(closurePercentage, privacy: .public), start=\(start, privacy: .public), dist=\(dist, privacy: .public), predictedTime=\(String(format: "%.1f", predictedTime), privacy: .public)s at \(String(format: "%.3f", speed), privacy: .public)s/%)")
        return .result()
    }
}
