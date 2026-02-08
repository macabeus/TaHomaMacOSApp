import AppIntents
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.tahoma-macos-app", category: "DeviceStore")

// MARK: - BlindDevice Entity

struct BlindDevice: AppEntity, Codable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Blind"
    static var defaultQuery = BlindDeviceQuery()

    var id: String          // deviceURL
    var label: String
    var controllableName: String
    var iconType: BlindIconType
    var favorites: [FavoritePosition]
    var secondsPerPercent: Double?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(label)", subtitle: "\(controllableName)")
    }

    /// Returns the stored speed or the global default fallback.
    var effectiveSecondsPerPercent: Double {
        secondsPerPercent ?? PendingCommand.defaultSecondsPerPercent
    }

    init(id: String, label: String, controllableName: String, iconType: BlindIconType = .estore, favorites: [FavoritePosition] = [], secondsPerPercent: Double? = nil) {
        self.id = id
        self.label = label
        self.controllableName = controllableName
        self.iconType = iconType
        self.favorites = favorites
        self.secondsPerPercent = secondsPerPercent
    }

    // MARK: - Codable (backward-compatible)

    enum CodingKeys: String, CodingKey {
        case id, label, controllableName, iconType, favorites, secondsPerPercent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        controllableName = try container.decode(String.self, forKey: .controllableName)
        iconType = try container.decodeIfPresent(BlindIconType.self, forKey: .iconType) ?? .estore
        favorites = try container.decodeIfPresent([FavoritePosition].self, forKey: .favorites) ?? []
        secondsPerPercent = try container.decodeIfPresent(Double.self, forKey: .secondsPerPercent)
    }
}

// MARK: - Query

struct BlindDeviceQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [BlindDevice] {
        logger.error("BlindDeviceQuery.entities(for: \(identifiers, privacy: .public))")
        let all = DeviceStore.loadAll()
        let filtered = all.filter { identifiers.contains($0.id) }
        logger.error("BlindDeviceQuery.entities: found \(filtered.count, privacy: .public) of \(all.count, privacy: .public) total")
        return filtered
    }

    func suggestedEntities() async throws -> [BlindDevice] {
        logger.error("BlindDeviceQuery.suggestedEntities() called")
        let all = DeviceStore.loadAll()
        logger.error("BlindDeviceQuery.suggestedEntities: returning \(all.count, privacy: .public) devices")
        for device in all {
            logger.error("  - device: \(device.label, privacy: .public) (id: \(device.id, privacy: .public))")
        }
        return all
    }
}

// MARK: - DeviceStore (Keychain-based)

enum DeviceStore {
    private static let storeKey = "savedDevices"

    static func loadAll() -> [BlindDevice] {
        guard let json = KeychainHelper.load(forKey: storeKey) else {
            logger.error("DeviceStore.loadAll: no data in keychain for '\(storeKey, privacy: .public)'")
            return []
        }

        logger.error("DeviceStore.loadAll: got \(json.count, privacy: .public) chars from keychain")

        guard let data = json.data(using: .utf8) else { return [] }
        let devices = (try? JSONDecoder().decode([BlindDevice].self, from: data)) ?? []
        logger.error("DeviceStore.loadAll: decoded \(devices.count, privacy: .public) devices")
        return devices
    }

    static func saveAll(_ devices: [BlindDevice]) {
        guard let data = try? JSONEncoder().encode(devices),
              let json = String(data: data, encoding: .utf8) else {
            logger.error("DeviceStore.saveAll: failed to encode \(devices.count, privacy: .public) devices")
            return
        }
        logger.error("DeviceStore.saveAll: saving \(devices.count, privacy: .public) devices (\(json.count, privacy: .public) chars)")
        KeychainHelper.save(json, forKey: storeKey)
    }

    static func addOrUpdate(_ device: BlindDevice) {
        logger.error("DeviceStore.addOrUpdate: \(device.label, privacy: .public) (id: \(device.id, privacy: .public))")
        var devices = loadAll()
        if let idx = devices.firstIndex(where: { $0.id == device.id }) {
            devices[idx] = device
        } else {
            devices.append(device)
        }
        saveAll(devices)
    }

    static func remove(id: String) {
        logger.error("DeviceStore.remove: \(id, privacy: .public)")
        var devices = loadAll()
        devices.removeAll { $0.id == id }
        saveAll(devices)
    }

    /// Returns the calibrated speed for a device, or the global default.
    static func speedForDevice(_ deviceURL: String) -> Double {
        let devices = loadAll()
        return devices.first(where: { $0.id == deviceURL })?.effectiveSecondsPerPercent
            ?? PendingCommand.defaultSecondsPerPercent
    }
}
