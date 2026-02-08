import Foundation

// MARK: - AnyCodableValue

/// A type-erased Codable value that handles all JSON value types from the API.
enum AnyCodableValue: Codable, Equatable {
    case int(Int)
    case string(String)
    case bool(Bool)
    case double(Double)
    case array([AnyCodableValue])
    case object([String: AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let boolVal = try? container.decode(Bool.self) {
            self = .bool(boolVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            self = .double(doubleVal)
        } else if let stringVal = try? container.decode(String.self) {
            self = .string(stringVal)
        } else if let arrayVal = try? container.decode([AnyCodableValue].self) {
            self = .array(arrayVal)
        } else if let objectVal = try? container.decode([String: AnyCodableValue].self) {
            self = .object(objectVal)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let val): try container.encode(val)
        case .string(let val): try container.encode(val)
        case .bool(let val): try container.encode(val)
        case .double(let val): try container.encode(val)
        case .array(let val): try container.encode(val)
        case .object(let val): try container.encode(val)
        case .null: try container.encodeNil()
        }
    }

    var intValue: Int? {
        if case .int(let val) = self { return val }
        if case .double(let val) = self { return Int(val) }
        return nil
    }

    var stringValue: String? {
        if case .string(let val) = self { return val }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let val) = self { return val }
        return nil
    }
}

// MARK: - Device

struct TaHomaDevice: Codable {
    let deviceURL: String
    let label: String
    let controllableName: String
    let available: Bool
    let states: [DeviceState]
}

struct DeviceState: Codable {
    let name: String
    let type: Int
    let value: AnyCodableValue
}

// MARK: - Commands

struct CommandRequest: Codable {
    let label: String
    let actions: [Action]
}

struct Action: Codable {
    let deviceURL: String
    let commands: [Command]
}

struct Command: Codable {
    let name: String
    let parameters: [Int]
}

struct ExecutionResponse: Codable {
    let execId: String
}

// MARK: - Blind State

struct BlindState {
    let closure: Int        // 0 = fully open, 100 = fully closed
    let openClosed: String  // "open", "closed"
    let isMoving: Bool

    static let unknown = BlindState(closure: -1, openClosed: "unknown", isMoving: false)

    static func from(states: [DeviceState]) -> BlindState {
        var closure = -1
        var openClosed = "unknown"
        var isMoving = false

        for state in states {
            switch state.name {
            case "core:ClosureState":
                closure = state.value.intValue ?? -1
            case "core:OpenClosedState":
                openClosed = state.value.stringValue ?? "unknown"
            case "core:MovingState":
                isMoving = state.value.boolValue ?? false
            default:
                break
            }
        }

        return BlindState(closure: closure, openClosed: openClosed, isMoving: isMoving)
    }

    static func cacheKey(forDevice deviceURL: String) -> String {
        let sanitized = deviceURL
            .replacingOccurrences(of: "://", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        return "cache_\(sanitized)"
    }

    func cacheToDefaults(forDevice deviceURL: String) {
        let key = BlindState.cacheKey(forDevice: deviceURL)
        let ts = Date().timeIntervalSince1970
        let json = "{\"closure\":\(closure),\"openClosed\":\"\(openClosed)\",\"isMoving\":\(isMoving),\"ts\":\(ts)}"
        KeychainHelper.save(json, forKey: key)
    }

    static func fromCache(forDevice deviceURL: String) -> BlindState {
        let key = cacheKey(forDevice: deviceURL)
        guard let json = KeychainHelper.load(forKey: key),
              let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .unknown
        }
        return BlindState(
            closure: dict["closure"] as? Int ?? -1,
            openClosed: dict["openClosed"] as? String ?? "unknown",
            isMoving: dict["isMoving"] as? Bool ?? false
        )
    }

    /// Seconds since the cache was last written for this device.
    static func cacheAge(forDevice deviceURL: String) -> TimeInterval {
        let key = cacheKey(forDevice: deviceURL)
        guard let json = KeychainHelper.load(forKey: key),
              let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ts = dict["ts"] as? Double else {
            return .infinity
        }
        return Date().timeIntervalSince1970 - ts
    }
}

// MARK: - Pending Command

/// Tracks an in-flight command sent by an intent so the timeline provider
/// can determine whether the blind is still moving toward a target position.
///
/// Lifecycle:
///  1. Open/Close/SetPosition intents call `PendingCommand.save(...)` with the target closure.
///  2. The timeline provider reads this via `PendingCommand.load(...)`.
///     - If the API position hasn't reached the target yet → blind is moving, poll every 5s.
///     - If the API position matches the target (within tolerance) → clear the pending command → idle.
///  3. The Stop intent calls `PendingCommand.clear(...)` to cancel tracking.
///
/// The pending command expires automatically after `maxAge` seconds as a safety net.
struct PendingCommand: Codable {
    let targetClosure: Int   // 0 = open, 100 = closed
    let startClosure: Int    // position when the command was sent
    let sentAt: TimeInterval // Date().timeIntervalSince1970

    /// Maximum age in seconds before the pending command is considered stale.
    static let maxAge: TimeInterval = 120

    /// Tolerance: if |apiClosure - target| <= this, the blind has "arrived".
    static let arrivalTolerance = 2

    /// Fallback speed when we can't calculate from observed movement.
    /// Real speed is ~0.355s/% — set slightly faster so the widget
    /// transitions to idle just before the blind physically arrives.
    static let defaultSecondsPerPercent = 0.33

    private static func keychainKey(forDevice deviceURL: String) -> String {
        let sanitized = deviceURL
            .replacingOccurrences(of: "://", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        return "pending_\(sanitized)"
    }

    func save(forDevice deviceURL: String) {
        let key = PendingCommand.keychainKey(forDevice: deviceURL)
        let json = "{\"targetClosure\":\(targetClosure),\"startClosure\":\(startClosure),\"sentAt\":\(sentAt)}"
        KeychainHelper.save(json, forKey: key)
    }

    /// Returns the pending command if it exists and hasn't expired.
    static func load(forDevice deviceURL: String) -> PendingCommand? {
        let key = keychainKey(forDevice: deviceURL)
        guard let json = KeychainHelper.load(forKey: key),
              let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let target = dict["targetClosure"] as? Int,
              let sentAt = dict["sentAt"] as? Double else {
            return nil
        }
        let age = Date().timeIntervalSince1970 - sentAt
        if age > maxAge { return nil }
        let start = dict["startClosure"] as? Int ?? target
        return PendingCommand(targetClosure: target, startClosure: start, sentAt: sentAt)
    }

    /// Calculates seconds-per-percent speed from observed movement, or returns default.
    func observedSpeed(currentClosure: Int) -> Double {
        let elapsed = Date().timeIntervalSince1970 - sentAt
        let moved = abs(currentClosure - startClosure)
        if moved >= 3 && elapsed > 0.5 {
            return elapsed / Double(moved)
        }
        return Self.defaultSecondsPerPercent
    }

    static func clear(forDevice deviceURL: String) {
        let key = keychainKey(forDevice: deviceURL)
        KeychainHelper.delete(forKey: key)
    }
}
