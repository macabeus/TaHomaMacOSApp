import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var gatewayPin = ""
    @State private var token = ""
    @State private var devices: [TaHomaDevice] = []
    @State private var savedDevices: [BlindDevice] = []
    @State private var selectedDeviceURL: String?
    @State private var showIconPicker = false
    @State private var showFavoritePicker = false
    @State private var isConnecting = false
    @State private var controller = BlindController()

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            if savedDevices.isEmpty && devices.isEmpty {
                onboardingPanel
            } else {
                HSplitView {
                    sidebarPanel
                    detailPanel
                }
            }
            Divider()
            statusBar
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(
            ZStack {
                AppColors.background
                RadialGradient(
                    colors: [Color.blue.opacity(0.08), Color.clear],
                    center: .top,
                    startRadius: 50,
                    endRadius: 450
                )
            }
            .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
        .onAppear(perform: loadSavedConfig)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                AnimatedBlindIcon(iconType: .estore, closureFraction: 0.3, size: 28)
                Text("TaHoma macOS App")
                    .font(AppTypography.appTitle)
                Spacer()
                if isConnected {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .font(AppTypography.appCaption)
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: Spacing.md) {
                TextField("Gateway PIN", text: $gatewayPin)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)

                SecureField("Bearer Token", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)

                Button {
                    Task { await connect() }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        if isConnecting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Connect")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(gatewayPin.isEmpty || token.isEmpty || isConnecting)

                Spacer()
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var isConnected: Bool {
        !devices.isEmpty
    }

    // MARK: - Onboarding

    private var onboardingPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue)
                    Text("Connect to your TaHoma gateway")
                        .font(AppTypography.appLargeTitle)
                    Text("Enter your gateway PIN and token above, then press Connect.")
                        .font(AppTypography.appBody)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.lg)

                onboardingStep(
                    number: 1,
                    title: "Find your gateway PIN",
                    lines: [
                        "Look at the bottom of your TaHoma Switch (or V2 / DIN Rail).",
                        "The PIN is printed on a label in the format XXXX-XXXX-XXXX.",
                        "It's also on the original packaging box."
                    ]
                )

                onboardingStep(
                    number: 2,
                    title: "Enable Developer Mode",
                    lines: [
                        "Open the TaHoma By Somfy app on your phone.",
                        "Go to your gateway settings.",
                        "Tap Help & advanced features, then Advanced features.",
                        "Tap the firmware version number 7 times to unlock Developer Mode."
                    ]
                )

                onboardingStep(
                    number: 3,
                    title: "Generate a token",
                    lines: [
                        "In the same menu, open the Developer Mode section.",
                        "Tap Generate a new token.",
                        "Copy the token immediately — it cannot be retrieved later."
                    ]
                )
            }
            .padding(Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func onboardingStep(number: Int, title: String, lines: [String]) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text("\(number)")
                .font(AppTypography.appTitle2)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.blue.opacity(0.6)))

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(title)
                    .font(AppTypography.appTitle2)
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(line)
                            .font(AppTypography.appBody)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .innerCardStyle()
    }

    // MARK: - Sidebar

    private var sidebarPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if !savedDevices.isEmpty {
                    sidebarSectionHeader("SAVED DEVICES")
                    ForEach(savedDevices, id: \.id) { device in
                        sidebarDeviceRow(device)
                    }
                }

                sidebarSectionHeader("DISCOVERED")
                let unsavedDevices = devices.filter { d in
                    !savedDevices.contains(where: { $0.id == d.deviceURL })
                }
                if unsavedDevices.isEmpty {
                    Text("Press Connect to discover devices.")
                        .font(AppTypography.appCaption2)
                        .italic()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Spacing.sm)
                } else {
                    ForEach(unsavedDevices, id: \.deviceURL) { device in
                        sidebarDiscoveredRow(device)
                    }
                }
            }
            .padding(Spacing.md)
        }
        .frame(minWidth: 180, idealWidth: 210, maxWidth: 250)
        .background(Color.white.opacity(0.03))
    }

    private func sidebarSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.appCaption2)
            .foregroundStyle(.secondary)
            .padding(.top, Spacing.xs)
    }

    private func sidebarDeviceRow(_ device: BlindDevice) -> some View {
        let isSelected = selectedDeviceURL == device.id
        return Button {
            selectDevice(device.id)
        } label: {
            HStack(spacing: Spacing.sm) {
                BlindIconView(
                    iconType: device.iconType,
                    closureFraction: 0.5,
                    tintColor: isSelected ? .white : BlindColors.partial,
                    size: 20
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(device.label)
                        .font(AppTypography.appCaption)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)
                    if let speed = device.secondsPerPercent {
                        Text(String(format: "%.2f s/%%", speed))
                            .font(AppTypography.appCaption2)
                            .foregroundStyle(isSelected ? .white.opacity(0.8) : .green)
                    } else {
                        Text("Uncalibrated")
                            .font(AppTypography.appCaption2)
                            .foregroundStyle(isSelected ? .white.opacity(0.8) : .orange)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs + 2)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.small)
                    .fill(isSelected ? Color.blue.opacity(0.5) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sidebarDiscoveredRow(_ device: TaHomaDevice) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "circle.dotted")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(device.label)
                .font(AppTypography.appCaption)
                .lineLimit(1)
            Spacer()
            Button {
                addDevice(device)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.borderless)
            .help("Add device")
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs + 2)
    }

    // MARK: - Detail Panel

    private var detailPanel: some View {
        Group {
            if let deviceURL = selectedDeviceURL,
               let device = savedDevices.first(where: { $0.id == deviceURL }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        deviceHeaderDetail(device: device)
                        Divider().opacity(0.3)
                        controlButtonsDetail(deviceURL: deviceURL)
                        Divider().opacity(0.3)
                        speedCalibrationDetail(device: device, deviceURL: deviceURL)
                        Divider().opacity(0.3)
                        favoritePositionsDetail(device: device, deviceURL: deviceURL)
                        Divider().opacity(0.3)
                        iconTypeDetail(device: device)
                        Divider().opacity(0.3)
                        removeDeviceDetail(deviceURL: deviceURL)
                    }
                    .padding(Spacing.xl)
                }
            } else {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Select a device")
                        .font(AppTypography.appHeadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Detail Sections

    private func deviceHeaderDetail(device: BlindDevice) -> some View {
        HStack(spacing: Spacing.lg) {
            if let state = controller.blindState {
                let fraction = state.closure >= 0 ? CGFloat(state.closure) / 100.0 : 0.5
                let color = BlindColors.stateColor(closure: state.closure, isMoving: state.isMoving)

                AnimatedBlindIcon(
                    iconType: device.iconType,
                    closureFraction: fraction,
                    isMoving: state.isMoving,
                    tintColor: color,
                    size: 64
                )

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(device.label)
                        .font(AppTypography.appTitle2)

                    Text(stateLabel(state))
                        .font(AppTypography.appHeadline)
                        .foregroundStyle(color)

                    if state.closure >= 0 {
                        testPercentageBar(closure: state.closure, color: color)
                    }

                    if state.isMoving {
                        Label("Moving...", systemImage: "arrow.up.arrow.down")
                            .font(AppTypography.appCaption)
                            .foregroundStyle(BlindColors.moving)
                    }
                }
            } else {
                BlindIconView(
                    iconType: device.iconType,
                    closureFraction: 0.5,
                    tintColor: BlindColors.partial,
                    size: 64
                )
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(device.label)
                        .font(AppTypography.appTitle2)
                    Text("No state loaded")
                        .font(AppTypography.appCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    private func controlButtonsDetail(deviceURL: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("Controls", icon: "slider.horizontal.3")

            HStack(spacing: Spacing.md) {
                Button {
                    Task { await controller.sendCommand("open", deviceURL: deviceURL, gatewayPin: gatewayPin, token: token) }
                } label: {
                    Label("Open", systemImage: "chevron.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(BlindColors.open)
                .disabled(controller.isLoading)

                Button {
                    Task { await controller.sendCommand("stop", deviceURL: deviceURL, gatewayPin: gatewayPin, token: token) }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(controller.isLoading)

                Button {
                    Task { await controller.sendCommand("close", deviceURL: deviceURL, gatewayPin: gatewayPin, token: token) }
                } label: {
                    Label("Close", systemImage: "chevron.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(BlindColors.closed)
                .disabled(controller.isLoading)

                Button {
                    Task { await controller.refreshState(deviceURL: deviceURL, gatewayPin: gatewayPin, token: token) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(controller.isLoading)
            }
        }
    }

    private func speedCalibrationDetail(device: BlindDevice, deviceURL: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("Speed Calibration", icon: "gauge.with.needle")

            if let speed = device.secondsPerPercent {
                let fullTravel = speed * 100
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(String(format: "%.3f s/%% (~%.0fs full travel)", speed, fullTravel))
                        .font(AppTypography.appBody)
                }
            } else {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Not calibrated")
                        .font(AppTypography.appBody)
                }
            }

            if controller.isCalibrating {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text(controller.calibrationProgress)
                        .font(AppTypography.appCaption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: Spacing.md) {
                    Button {
                        Task { await runCalibration(deviceURL: deviceURL) }
                    } label: {
                        Label("Calibrate", systemImage: "gauge.with.needle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(gatewayPin.isEmpty || token.isEmpty)

                    if device.secondsPerPercent != nil {
                        Button {
                            resetCalibration(deviceId: deviceURL)
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                }
            }
        }
    }

    private func favoritePositionsDetail(device: BlindDevice, deviceURL: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("Favorite Positions", icon: "star.circle.fill")

            if device.favorites.isEmpty {
                Text("No favorites saved yet.")
                    .font(AppTypography.appCaption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(device.favorites) { fav in
                    HStack(spacing: Spacing.md) {
                        Image(systemName: fav.sfSymbol)
                            .font(.title3)
                            .frame(width: 28)

                        Text("\(100 - fav.closurePercentage)% open")
                            .font(AppTypography.appBody)

                        Spacer()

                        Button {
                            removeFavorite(deviceId: deviceURL, favoriteId: fav.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.borderless)
                        .help("Remove favorite")
                    }
                    .innerCardStyle()
                }
            }

            if device.favorites.count >= 2 {
                Text("Maximum 2 favorites per device.")
                    .font(AppTypography.appCaption)
                    .foregroundStyle(.secondary)
            } else if controller.blindState != nil && controller.blindState!.closure >= 0 {
                if showFavoritePicker {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Choose an icon for \(100 - controller.blindState!.closure)% open:")
                            .font(AppTypography.appCaption)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Spacing.sm) {
                            ForEach(FavoriteSymbols.all, id: \.symbol) { item in
                                Button {
                                    saveFavorite(deviceId: deviceURL, closurePercentage: controller.blindState!.closure, sfSymbol: item.symbol)
                                } label: {
                                    VStack(spacing: Spacing.xs) {
                                        Image(systemName: item.symbol)
                                            .font(.title3)
                                        Text(item.label)
                                            .font(AppTypography.appCaption2)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(Spacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.small)
                                            .fill(AppColors.innerCardBackground)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.small)
                                            .stroke(AppColors.innerCardBorder, lineWidth: 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showFavoritePicker = true
                        }
                    } label: {
                        Label("Save Current Position", systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
            }
        }
    }

    private func iconTypeDetail(device: BlindDevice) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("Icon Type", icon: "paintbrush")

            HStack(spacing: Spacing.md) {
                ForEach(BlindIconType.allCases, id: \.self) { iconType in
                    let isSelected = device.iconType == iconType
                    Button {
                        updateIconType(deviceId: device.id, iconType: iconType)
                    } label: {
                        VStack(spacing: Spacing.xs) {
                            BlindIconView(
                                iconType: iconType,
                                closureFraction: 0.4,
                                tintColor: isSelected ? .blue : .secondary,
                                size: 40
                            )
                            Text(iconType.displayName)
                                .font(AppTypography.appCaption2)
                                .foregroundStyle(isSelected ? .primary : .secondary)
                        }
                        .padding(Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppCornerRadius.small)
                                .fill(isSelected ? Color.blue.opacity(0.12) : AppColors.innerCardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.small)
                                .stroke(isSelected ? Color.blue : AppColors.innerCardBorder, lineWidth: isSelected ? 1.5 : 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func removeDeviceDetail(deviceURL: String) -> some View {
        HStack {
            Spacer()
            Button(role: .destructive) {
                removeDevice(id: deviceURL)
            } label: {
                Label("Remove Device", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)
            Spacer()
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            if !controller.statusMessage.isEmpty {
                Text(controller.statusMessage)
                    .foregroundStyle(controller.statusMessage.starts(with: "Error") ? .red : .secondary)
                    .font(AppTypography.appCaption)
                    .transition(.opacity)
            }

            Spacer()

            if controller.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(AppTypography.appHeadline)
    }

    private func stateLabel(_ state: BlindState) -> String {
        if state.isMoving { return "Moving" }
        switch state.closure {
        case 0: return "Open"
        case 100: return "Closed"
        case let c where c > 0: return "Partially Open (\(c)%)"
        default: return state.openClosed.capitalized
        }
    }

    private func testPercentageBar(closure: Int, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.08))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * (1.0 - CGFloat(closure) / 100.0))
            }
        }
        .frame(height: 6)
    }

    // MARK: - Device Selection

    private func selectDevice(_ deviceURL: String) {
        selectedDeviceURL = deviceURL
        showIconPicker = false
        showFavoritePicker = false
        if !gatewayPin.isEmpty && !token.isEmpty {
            Task { await controller.refreshState(deviceURL: deviceURL, gatewayPin: gatewayPin, token: token) }
        }
    }

    // MARK: - Device Management

    private func addDevice(_ device: TaHomaDevice) {
        let blind = BlindDevice(id: device.deviceURL, label: device.label, controllableName: device.controllableName)
        DeviceStore.addOrUpdate(blind)
        savedDevices = DeviceStore.loadAll()
        WidgetCenter.shared.reloadTimelines(ofKind: SharedConfig.widgetKind)
        selectDevice(device.deviceURL)
    }

    private func removeDevice(id: String) {
        DeviceStore.remove(id: id)
        savedDevices = DeviceStore.loadAll()
        if selectedDeviceURL == id {
            if let first = savedDevices.first {
                selectDevice(first.id)
            } else {
                selectedDeviceURL = nil
                controller.blindState = nil
            }
        }
        WidgetCenter.shared.reloadTimelines(ofKind: SharedConfig.widgetKind)
    }

    private func saveFavorite(deviceId: String, closurePercentage: Int, sfSymbol: String) {
        guard var device = savedDevices.first(where: { $0.id == deviceId }) else { return }
        guard device.favorites.count < 2 else { return }
        let fav = FavoritePosition(id: UUID(), closurePercentage: closurePercentage, sfSymbol: sfSymbol)
        device.favorites.append(fav)
        DeviceStore.addOrUpdate(device)
        savedDevices = DeviceStore.loadAll()
        withAnimation(.easeInOut(duration: 0.2)) {
            showFavoritePicker = false
        }
        WidgetCenter.shared.reloadTimelines(ofKind: SharedConfig.widgetKind)
    }

    private func removeFavorite(deviceId: String, favoriteId: UUID) {
        guard var device = savedDevices.first(where: { $0.id == deviceId }) else { return }
        device.favorites.removeAll { $0.id == favoriteId }
        DeviceStore.addOrUpdate(device)
        savedDevices = DeviceStore.loadAll()
        WidgetCenter.shared.reloadTimelines(ofKind: SharedConfig.widgetKind)
    }

    private func updateIconType(deviceId: String, iconType: BlindIconType) {
        guard var device = savedDevices.first(where: { $0.id == deviceId }) else { return }
        device.iconType = iconType
        DeviceStore.addOrUpdate(device)
        savedDevices = DeviceStore.loadAll()
        WidgetCenter.shared.reloadTimelines(ofKind: SharedConfig.widgetKind)
    }

    private func runCalibration(deviceURL: String) async {
        guard let measuredSpeed = await controller.calibrate(deviceURL: deviceURL, gatewayPin: gatewayPin, token: token) else { return }
        guard var device = savedDevices.first(where: { $0.id == deviceURL }) else { return }
        device.secondsPerPercent = measuredSpeed
        DeviceStore.addOrUpdate(device)
        savedDevices = DeviceStore.loadAll()
        WidgetCenter.shared.reloadTimelines(ofKind: SharedConfig.widgetKind)
    }

    private func resetCalibration(deviceId: String) {
        guard var device = savedDevices.first(where: { $0.id == deviceId }) else { return }
        device.secondsPerPercent = nil
        DeviceStore.addOrUpdate(device)
        savedDevices = DeviceStore.loadAll()
        WidgetCenter.shared.reloadTimelines(ofKind: SharedConfig.widgetKind)
    }

    // MARK: - Actions

    private func loadSavedConfig() {
        #if EMPTY_STATE_PREVIEW
        // Skip loading saved data so the onboarding empty state is visible
        return
        #else
        gatewayPin = KeychainHelper.loadGatewayPin() ?? ""
        token = KeychainHelper.loadToken() ?? ""
        savedDevices = DeviceStore.loadAll()

        if savedDevices.isEmpty, let legacyURL = KeychainHelper.loadDeviceURL() {
            let migrated = BlindDevice(id: legacyURL, label: "Blind", controllableName: "Migrated")
            DeviceStore.addOrUpdate(migrated)
            savedDevices = DeviceStore.loadAll()
            KeychainHelper.delete(forKey: "deviceURL")
        }

        if let first = savedDevices.first {
            selectedDeviceURL = first.id
        }

        if let deviceURL = selectedDeviceURL, !gatewayPin.isEmpty && !token.isEmpty {
            Task { await controller.refreshState(deviceURL: deviceURL, gatewayPin: gatewayPin, token: token) }
        }
        #endif
    }

    private func connect() async {
        isConnecting = true
        controller.statusMessage = ""
        defer { isConnecting = false }

        let client = TaHomaClient(gatewayPin: gatewayPin, token: token)
        do {
            let allDevices = try await client.listDevices()
            devices = allDevices.filter { $0.controllableName.contains("RollerShutter") || $0.controllableName.contains("Blind") || $0.controllableName.contains("Screen") || $0.controllableName.contains("ExteriorVenetianBlind") }

            if devices.isEmpty {
                devices = allDevices
                controller.statusMessage = "No roller shutter devices found. Showing all \(allDevices.count) devices."
            } else {
                controller.statusMessage = "Found \(devices.count) blind/shutter devices."
            }

            KeychainHelper.saveGatewayPin(gatewayPin)
            KeychainHelper.saveToken(token)
        } catch {
            controller.statusMessage = "Error: \(error.localizedDescription)"
        }
    }
}
