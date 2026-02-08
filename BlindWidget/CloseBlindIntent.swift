import AppIntents
import OSLog
import WidgetKit

private let logger = Logger(subsystem: "com.tahoma-macos-app", category: "CloseBlindIntent")

struct CloseBlindIntent: AppIntent {
    static var title: LocalizedStringResource = "Close Blind"
    static var description = IntentDescription("Closes the roller blind.")

    @Parameter(title: "Device URL")
    var deviceURL: String

    init() {
        self.deviceURL = ""
    }

    init(deviceURL: String) {
        self.deviceURL = deviceURL
    }

    func perform() async throws -> some IntentResult {
        logger.error("[perform] deviceURL=\(deviceURL, privacy: .public)")
        guard !deviceURL.isEmpty else { return .result() }

        // Optimistic: save state FIRST so the timeline updates instantly.
        let startClosure = BlindState.fromCache(forDevice: deviceURL).closure
        let start = max(0, startClosure)
        let dist = abs(100 - start)
        let speed = DeviceStore.speedForDevice(deviceURL)
        let predictedTime = Double(dist) * speed
        PendingCommand(targetClosure: 100, startClosure: start, sentAt: Date().timeIntervalSince1970)
            .save(forDevice: deviceURL)
        BlindState(closure: 100, openClosed: "closed", isMoving: true)
            .cacheToDefaults(forDevice: deviceURL)

        // Fire command in background — we expect it to succeed.
        if let client = TaHomaClient.fromKeychain() {
            Task { try? await client.sendCommand(deviceURL: deviceURL, command: "close") }
        }

        logger.error("[perform] CLOSE saved pending(target=100, start=\(start, privacy: .public), dist=\(dist, privacy: .public), predictedTime=\(String(format: "%.1f", predictedTime), privacy: .public)s at \(String(format: "%.3f", speed), privacy: .public)s/%)")
        return .result()
    }
}
