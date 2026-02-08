import Foundation
import WidgetKit

@Observable
final class BlindController {
    var blindState: BlindState?
    var statusMessage = ""
    var isLoading = false
    var isCalibrating = false
    var calibrationProgress = ""

    private var pollingTask: Task<Void, Never>?

    func sendCommand(_ command: String, deviceURL: String, gatewayPin: String, token: String) async {
        // Cancel any previous polling
        pollingTask?.cancel()

        isLoading = true
        statusMessage = ""

        let startClosure = blindState?.closure ?? -1
        let client = TaHomaClient(gatewayPin: gatewayPin, token: token)
        do {
            let execId = try await client.sendCommand(deviceURL: deviceURL, command: command)
            statusMessage = "Command '\(command)' sent (exec: \(execId))"

            // Immediately set target state — AnimatedBlindIcon will animate toward it
            switch command {
            case "open":
                blindState = BlindState(closure: 0, openClosed: "open", isMoving: true)
            case "close":
                blindState = BlindState(closure: 100, openClosed: "closed", isMoving: true)
            default:
                break
            }
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
        isLoading = false

        // Poll in the background — buttons stay enabled so user can press Stop
        pollingTask = Task {
            await pollUntilPositionChanged(client: client, deviceURL: deviceURL, startClosure: startClosure)
            WidgetCenter.shared.reloadTimelines(ofKind: SharedConfig.widgetKind)
        }
    }

    func sendSetClosure(_ closurePercentage: Int, deviceURL: String, gatewayPin: String, token: String) async {
        pollingTask?.cancel()

        isLoading = true
        statusMessage = ""

        let startClosure = blindState?.closure ?? -1
        let client = TaHomaClient(gatewayPin: gatewayPin, token: token)
        do {
            let execId = try await client.sendCommand(deviceURL: deviceURL, command: "setClosure", parameters: [closurePercentage])
            statusMessage = "Command 'setClosure(\(closurePercentage))' sent (exec: \(execId))"
            blindState = BlindState(closure: closurePercentage, openClosed: closurePercentage == 0 ? "open" : "closed", isMoving: true)
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
        isLoading = false

        pollingTask = Task {
            await pollUntilPositionChanged(client: client, deviceURL: deviceURL, startClosure: startClosure)
            WidgetCenter.shared.reloadTimelines(ofKind: SharedConfig.widgetKind)
        }
    }

    func refreshState(deviceURL: String, gatewayPin: String, token: String) async {
        isLoading = true
        defer { isLoading = false }

        let client = TaHomaClient(gatewayPin: gatewayPin, token: token)
        do {
            let states = try await client.getDeviceState(deviceURL: deviceURL)
            blindState = BlindState.from(states: states)
            blindState?.cacheToDefaults(forDevice: deviceURL)
        } catch {
            statusMessage = "Error refreshing state: \(error.localizedDescription)"
        }
    }

    /// Moves the blind a large distance, measures elapsed time, and returns seconds-per-percent.
    func calibrate(deviceURL: String, gatewayPin: String, token: String) async -> Double? {
        isCalibrating = true
        calibrationProgress = "Reading current position..."
        defer { isCalibrating = false }

        let client = TaHomaClient(gatewayPin: gatewayPin, token: token)

        // 1. Fetch current position
        let startPosition: Int
        do {
            let states = try await client.getDeviceState(deviceURL: deviceURL)
            let state = BlindState.from(states: states)
            guard state.closure >= 0 else {
                statusMessage = "Calibration failed: could not read current position."
                return nil
            }
            startPosition = state.closure
        } catch {
            statusMessage = "Calibration failed: \(error.localizedDescription)"
            return nil
        }

        // 2. Choose target to maximize distance
        let target: Int
        let command: String
        if startPosition <= 50 {
            target = 100
            command = "close"
        } else {
            target = 0
            command = "open"
        }

        let distance = abs(target - startPosition)
        guard distance >= 20 else {
            statusMessage = "Calibration failed: need at least 20% distance (current: \(startPosition)%, target: \(target)%)."
            return nil
        }

        // 3. Send command and start timer
        calibrationProgress = "Moving blind \(command)... (\(startPosition)%)"
        let startTime = Date()
        do {
            _ = try await client.sendCommand(deviceURL: deviceURL, command: command)
        } catch {
            statusMessage = "Calibration failed: \(error.localizedDescription)"
            return nil
        }

        // 4. Poll until arrival or timeout
        let maxDuration: TimeInterval = 120
        while !Task.isCancelled && Date().timeIntervalSince(startTime) < maxDuration {
            try? await Task.sleep(for: .seconds(2))

            do {
                let states = try await client.getDeviceState(deviceURL: deviceURL)
                let apiState = BlindState.from(states: states)

                if apiState.closure >= 0 {
                    calibrationProgress = "Moving blind \(command)... (\(apiState.closure)%)"
                    blindState = apiState
                }

                let remaining = abs(apiState.closure - target)
                if remaining <= PendingCommand.arrivalTolerance {
                    let elapsed = Date().timeIntervalSince(startTime)
                    let measuredSpeed = elapsed / Double(distance)
                    calibrationProgress = ""
                    statusMessage = "Calibration complete: \(String(format: "%.3f", measuredSpeed)) s/%"
                    blindState = apiState
                    apiState.cacheToDefaults(forDevice: deviceURL)
                    return measuredSpeed
                }
            } catch {
                continue
            }
        }

        calibrationProgress = ""
        statusMessage = "Calibration timed out after \(Int(maxDuration))s."
        return nil
    }

    private func pollUntilPositionChanged(client: TaHomaClient, deviceURL: String, startClosure: Int) async {
        let maxDuration: TimeInterval = 60
        let startTime = Date()

        while !Task.isCancelled && Date().timeIntervalSince(startTime) < maxDuration {
            try? await Task.sleep(for: .seconds(2))

            do {
                let states = try await client.getDeviceState(deviceURL: deviceURL)
                let apiState = BlindState.from(states: states)

                // The blind only reports a new closure value once it has fully stopped.
                // A changed value is the most reliable indicator that movement is complete.
                if startClosure >= 0 && apiState.closure != startClosure {
                    blindState = apiState
                    apiState.cacheToDefaults(forDevice: deviceURL)
                    break
                }
            } catch {
                continue
            }
        }
    }
}
