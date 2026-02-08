import AppIntents
import OSLog
import WidgetKit

private let logger = Logger(subsystem: "com.tahoma-macos-app", category: "StopBlindIntent")

struct StopBlindIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Blind"
    static var description = IntentDescription("Stops the roller blind movement.")

    @Parameter(title: "Device URL")
    var deviceURL: String

    init() {
        self.deviceURL = ""
    }

    init(deviceURL: String) {
        self.deviceURL = deviceURL
    }

    func perform() async throws -> some IntentResult {
        logger.error("[perform] STOP deviceURL=\(deviceURL, privacy: .public)")
        guard !deviceURL.isEmpty else { return .result() }

        // Optimistic: clear pending and mark idle FIRST so the timeline updates instantly.
        PendingCommand.clear(forDevice: deviceURL)
        let cached = BlindState.fromCache(forDevice: deviceURL)
        let currentClosure = max(0, cached.closure)
        let oc = currentClosure == 0 ? "open" : (currentClosure >= 100 ? "closed" : cached.openClosed)
        BlindState(closure: currentClosure, openClosed: oc, isMoving: false)
            .cacheToDefaults(forDevice: deviceURL)

        // Fire stop command in background — we expect it to succeed.
        if let client = TaHomaClient.fromKeychain() {
            Task { try? await client.sendCommand(deviceURL: deviceURL, command: "stop") }
        }

        logger.error("[perform] STOP cleared pending, cached idle at \(currentClosure, privacy: .public), returning")
        return .result()
    }
}
