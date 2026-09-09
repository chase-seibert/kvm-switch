import AppKit
import SwiftUI

struct HardwareSnapshot {
    var monitor: ASUSMonitor?
    var currentInput: PA32QCVInput?
    var currentInputValue: Int?
    var cliInstalled = false
    var cliVersion: String?
    var errorMessage: String?

    static let empty = HardwareSnapshot()

    var isFound: Bool { monitor != nil }
    var isReady: Bool { cliInstalled && monitor != nil }

    var currentInputTitle: String {
        guard let currentInput else { return currentInputValue.map { "Unknown (\($0))" } ?? "Unknown" }
        return "\(currentInput.title) (\(currentInput.cliValue))"
    }
}

final class MainWindowModel: ObservableObject {
    @Published var hardware = HardwareSnapshot.empty
    @Published var isBusy = false
    @Published var isInstalling = false
    @Published var installationMessage: String?
    @Published var errorMessage: String?
}

final class MainWindowController {
    private let windowContentSize = NSSize(width: 560, height: 390)
    private let minimumWindowContentSize = NSSize(width: 500, height: 360)
    private let settingsContentSize = NSSize(width: 620, height: 520)
    private let minimumSettingsContentSize = NSSize(width: 560, height: 440)
    private let model = MainWindowModel()
    private let preferences: Preferences
    private let loginItem: LoginItemManager
    private let switchAction: (PA32QCVInput) -> Void
    private let refreshAction: () -> Void
    private let installAction: () -> Void
    private let finishSetupAction: () -> Void
    private var windowController: NSWindowController?
    private var settingsWindowController: NSWindowController?

    init(
        preferences: Preferences = .shared,
        loginItem: LoginItemManager = LoginItemManager(),
        switchAction: @escaping (PA32QCVInput) -> Void,
        refreshAction: @escaping () -> Void,
        installAction: @escaping () -> Void,
        finishSetupAction: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.loginItem = loginItem
        self.switchAction = switchAction
        self.refreshAction = refreshAction
        self.installAction = installAction
        self.finishSetupAction = finishSetupAction
    }

    func show() {
        if windowController == nil {
            let view = AppRootView(
                model: model,
                preferences: preferences,
                switchAction: { [weak self] input in self?.switchTo(input) },
                refreshAction: { [weak self] in self?.refreshAction() },
                installAction: { [weak self] in self?.installAction() },
                finishSetupAction: { [weak self] in self?.finishSetupAction() }
            )
            let hostingController = NSHostingController(
                rootView: view.frame(minWidth: minimumWindowContentSize.width, minHeight: minimumWindowContentSize.height, alignment: .topLeading)
            )
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: windowContentSize.width, height: windowContentSize.height),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            newWindow.contentViewController = hostingController
            newWindow.title = "ProArt KVM"
            newWindow.setContentSize(windowContentSize)
            newWindow.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            newWindow.isReleasedWhenClosed = false
            newWindow.isRestorable = false
            let targetFrameSize = newWindow.frameRect(forContentRect: NSRect(origin: .zero, size: minimumWindowContentSize)).size
            newWindow.minSize = targetFrameSize
            newWindow.center()
            windowController = NSWindowController(window: newWindow)
        }

        windowController?.showWindow(nil)
        if let window = windowController?.window {
            window.orderFrontRegardless()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettings() {
        if settingsWindowController == nil {
            let view = HardwareSettingsView(
                model: model,
                preferences: preferences,
                loginItem: loginItem,
                refreshAction: { [weak self] in self?.refreshAction() },
                installAction: { [weak self] in self?.installAction() },
                switchAction: { [weak self] input in self?.switchTo(input) }
            )
            let hostingController = NSHostingController(
                rootView: view.frame(minWidth: minimumSettingsContentSize.width, minHeight: minimumSettingsContentSize.height, alignment: .topLeading)
            )
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: settingsContentSize.width, height: settingsContentSize.height),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            newWindow.contentViewController = hostingController
            newWindow.title = "ProArt KVM Settings"
            newWindow.setContentSize(settingsContentSize)
            newWindow.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            newWindow.isReleasedWhenClosed = false
            newWindow.isRestorable = false
            let targetFrameSize = newWindow.frameRect(forContentRect: NSRect(origin: .zero, size: minimumSettingsContentSize)).size
            newWindow.minSize = targetFrameSize
            newWindow.center()
            settingsWindowController = NSWindowController(window: newWindow)
        }

        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func update(
        monitor: ASUSMonitor?,
        currentInput: PA32QCVInput?,
        currentInputValue: Int?,
        cliInstalled: Bool,
        cliVersion: String?,
        errorMessage: String? = nil
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            model.hardware = HardwareSnapshot(
                monitor: monitor,
                currentInput: currentInput,
                currentInputValue: currentInputValue,
                cliInstalled: cliInstalled,
                cliVersion: cliVersion,
                errorMessage: errorMessage
            )
            model.errorMessage = errorMessage
        }
    }

    func setBusy(_ busy: Bool) {
        DispatchQueue.main.async { [weak self] in self?.model.isBusy = busy }
    }

    func setInstalling(_ installing: Bool, message: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.model.isInstalling = installing
            self?.model.installationMessage = message
        }
    }

    func setError(_ message: String?) {
        DispatchQueue.main.async { [weak self] in self?.model.errorMessage = message }
    }

    private func switchTo(_ input: PA32QCVInput) {
        model.errorMessage = nil
        model.isBusy = true
        switchAction(input)
    }
}

private struct AppRootView: View {
    @ObservedObject var model: MainWindowModel
    @ObservedObject var preferences: Preferences
    let switchAction: (PA32QCVInput) -> Void
    let refreshAction: () -> Void
    let installAction: () -> Void
    let finishSetupAction: () -> Void

    var body: some View {
        Group {
            if preferences.onboardingCompleted {
                AppWindowView(
                    model: model,
                    preferences: preferences,
                    switchAction: switchAction
                )
            } else {
                OnboardingView(
                    model: model,
                    preferences: preferences,
                    refreshAction: refreshAction,
                    installAction: installAction,
                    finishSetupAction: finishSetupAction
                )
            }
        }
        .font(.system(size: 14 * preferences.fontScale))
    }
}

private struct OnboardingView: View {
    @ObservedObject var model: MainWindowModel
    @ObservedObject var preferences: Preferences
    let refreshAction: () -> Void
    let installAction: () -> Void
    let finishSetupAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("ProArt KVM setup", systemImage: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 25 * preferences.fontScale, weight: .semibold))
                    Text("Use ASUS Display Control to switch the PA32QCV input and its connected keyboard and mouse.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GroupBox("1. Install ASUS Display Control") {
                    HStack(spacing: 12) {
                        Image(systemName: model.hardware.cliInstalled ? "checkmark.circle.fill" : "arrow.down.circle")
                            .foregroundStyle(model.hardware.cliInstalled ? .green : .accentColor)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.hardware.cliInstalled ? "CLI installed" : "Download the official macOS CLI")
                            Text(model.hardware.cliInstalled ? (model.hardware.cliVersion ?? "Ready to use") : "The app keeps it in Application Support and does not modify your shell PATH.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(model.isInstalling ? "Downloading…" : (model.hardware.cliInstalled ? "Update" : "Download"), action: installAction)
                            .disabled(model.isInstalling)
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("2. Confirm the monitor") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let monitor = model.hardware.monitor {
                            Label("PA32QCV found", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            HardwareRow(label: "CLI monitor ID", value: String(monitor.id))
                            HardwareRow(label: "Device ID", value: String(monitor.deviceID))
                            HardwareRow(label: "Serial", value: monitor.serialNumber)
                        } else {
                            Label(model.hardware.cliInstalled ? "PA32QCV not found yet" : "Install the CLI first", systemImage: "display.trianglebadge.exclamationmark")
                                .foregroundStyle(.orange)
                        }
                        Button("Refresh monitor status", action: refreshAction)
                            .disabled(model.isInstalling)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox("3. Input source IDs") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(PA32QCVInput.allCases) { input in
                            HardwareRow(label: input.title, value: "InputSource \(input.cliValue)")
                        }
                        Text("These values are from ASUS Display Control’s PA32QCV-compatible CLI reference. Selecting an input also changes the monitor’s KVM upstream when configured in the OSD.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }

                if let message = model.installationMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Spacer()
                    Button("Finish Setup", action: finishSetupAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.hardware.isReady || model.isInstalling)
                }
            }
            .padding(28)
        }
        .onAppear(perform: refreshAction)
    }
}

private struct AppWindowView: View {
    @ObservedObject var model: MainWindowModel
    @ObservedObject var preferences: Preferences
    let switchAction: (PA32QCVInput) -> Void

    var body: some View {
        SwitcherView(model: model, preferences: preferences, switchAction: switchAction)
    }
}

private struct SwitcherView: View {
    @ObservedObject var model: MainWindowModel
    @ObservedObject var preferences: Preferences
    let switchAction: (PA32QCVInput) -> Void

    private var toggleInput: PA32QCVInput? {
        guard let role = preferences.role else { return nil }
        guard preferences.isInputEnabled(role.otherInput) else { return nil }
        return role.otherInput
    }

    private var visibleInputs: [PA32QCVInput] {
        PA32QCVInput.allCases.filter(preferences.isInputEnabled)
    }

    private var currentInputTitle: String {
        guard let currentInput = model.hardware.currentInput else {
            return model.hardware.currentInputTitle
        }
        return "\(preferences.displayName(for: currentInput)) (\(currentInput.cliValue))"
    }

    private var gridColumns: [GridItem] {
        let count = min(max(visibleInputs.count, 1), 3)
        return Array(repeating: GridItem(.flexible(minimum: 0)), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Switch the PA32QCV input")
                    .font(.system(size: 25 * preferences.fontScale, weight: .semibold))
                Text("The ASUS CLI changes the monitor input. The PA32QCV then follows its configured KVM upstream mapping for keyboard and mouse.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(visibleInputs) { input in
                    InputButton(
                        input: input,
                        name: preferences.displayName(for: input),
                        icon: preferences.iconChoice(for: input),
                        isSelected: model.hardware.currentInput == input,
                        isEnabled: model.hardware.isReady && !model.isBusy
                    ) {
                    switchAction(input)
                }
                }
            }

            HStack {
                Label(
                    model.hardware.isReady ? "PA32QCV ready" : (model.hardware.cliInstalled ? "PA32QCV not found" : "Setup required"),
                    systemImage: model.hardware.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(model.hardware.isReady ? .green : .orange)
                Spacer()
                Text("Current: \(currentInputTitle)")
                    .foregroundStyle(.secondary)
            }

            if let toggleInput {
                Button {
                    switchAction(toggleInput)
                } label: {
                    Label("Toggle to \(preferences.displayName(for: toggleInput))  ⌃⌥⌘K", systemImage: "arrow.left.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!model.hardware.isReady || model.isBusy)
            } else {
                Text("Choose this Mac’s connection role in Settings and enable its destination input to use the toggle shortcut.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(28)
    }
}

private struct InputButton: View {
    let input: PA32QCVInput
    let name: String
    let icon: InputIconChoice
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                InputIconView(choice: icon)
                    .font(.system(size: 30, weight: .medium))
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                Text("ID \(input.cliValue)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 126)
        }
        .buttonStyle(.borderedProminent)
        .tint(isSelected ? .accentColor : .gray)
        .controlSize(.large)
        .disabled(!isEnabled)
    }
}

private struct InputIconView: View {
    let choice: InputIconChoice

    @ViewBuilder
    var body: some View {
        if let systemImage = choice.systemImage {
            Image(systemName: systemImage)
        } else if let emoji = choice.emoji {
            Text(emoji)
        }
    }
}

private struct HardwareSettingsView: View {
    @ObservedObject var model: MainWindowModel
    @ObservedObject var preferences: Preferences
    @ObservedObject var loginItem: LoginItemManager
    let refreshAction: () -> Void
    let installAction: () -> Void
    let switchAction: (PA32QCVInput) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Settings & hardware")
                            .font(.system(size: 24 * preferences.fontScale, weight: .semibold))
                        Text("Manage the ASUS CLI, confirm the PA32QCV, and inspect the input IDs used by this app.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Refresh", action: refreshAction)
                        .buttonStyle(.bordered)
                }

                GroupBox("App") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Start ProArt KVM at login", isOn: Binding(
                            get: { loginItem.isEnabled },
                            set: { loginItem.setEnabled($0) }
                        ))
                        Text(loginItem.statusDescription)
                            .font(.callout)
                            .foregroundStyle(loginItem.requiresApproval ? .orange : .secondary)
                        if let errorMessage = loginItem.errorMessage {
                            Text(errorMessage)
                                .font(.callout)
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox("ASUS Display Control") {
                    VStack(alignment: .leading, spacing: 8) {
                        HardwareRow(label: "Status", value: model.hardware.cliInstalled ? "Installed" : "Not installed")
                        if let version = model.hardware.cliVersion {
                            HardwareRow(label: "Version", value: version)
                        }
                        HardwareRow(label: "Location", value: ASUSCLIManager.shared.installDirectoryURL.path)
                        HStack {
                            Spacer()
                            Button(model.isInstalling ? "Downloading…" : "Download / Update CLI", action: installAction)
                                .disabled(model.isInstalling)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox("Discovered hardware") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let monitor = model.hardware.monitor {
                            HardwareRow(label: "Display", value: monitor.model)
                            HardwareRow(label: "CLI monitor ID", value: String(monitor.id))
                            HardwareRow(label: "Device ID", value: String(monitor.deviceID))
                            HardwareRow(label: "Serial", value: monitor.serialNumber)
                        } else {
                            Label("No matching PA32QCV is currently discovered.", systemImage: "display.trianglebadge.exclamationmark")
                                .foregroundStyle(.orange)
                            Text("Connect the monitor, then choose Refresh. Discovery is performed by the ASUS CLI.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox("Input options — ASUS CLI InputSource") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(PA32QCVInput.allCases) { input in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 10) {
                                    InputIconView(choice: preferences.iconChoice(for: input))
                                        .font(.system(size: 21))
                                        .frame(width: 28, height: 28)
                                    VStack(alignment: .leading, spacing: 7) {
                                        HStack {
                                            TextField("Input name", text: Binding(
                                                get: { preferences.displayName(for: input) },
                                                set: {
                                                    var customization = preferences.customization(for: input)
                                                    customization.name = $0
                                                    preferences.setCustomization(customization, for: input)
                                                }
                                            ))
                                            .textFieldStyle(.roundedBorder)
                                            Text("ID \(input.cliValue)")
                                                .foregroundStyle(.secondary)
                                                .monospacedDigit()
                                        }
                                        HStack(spacing: 12) {
                                            Picker("Icon", selection: Binding(
                                                get: { preferences.iconChoice(for: input) },
                                                set: {
                                                    var customization = preferences.customization(for: input)
                                                    customization.icon = $0.rawValue
                                                    preferences.setCustomization(customization, for: input)
                                                }
                                            )) {
                                                ForEach(InputIconChoice.allCases) { choice in
                                                    HStack(spacing: 8) {
                                                        InputIconView(choice: choice)
                                                            .frame(width: 20)
                                                        Text(choice.title)
                                                    }
                                                    .tag(choice)
                                                }
                                            }
                                            .pickerStyle(.menu)

                                            Toggle("Show", isOn: Binding(
                                                get: { preferences.isInputEnabled(input) },
                                                set: { preferences.setInputEnabled(input, enabled: $0) }
                                            ))
                                            .toggleStyle(.switch)
                                            .controlSize(.small)
                                            Spacer()
                                            Button("Switch") { switchAction(input) }
                                                .buttonStyle(.bordered)
                                                .disabled(!model.hardware.isReady || model.isBusy)
                                        }
                                    }
                                }
                            }
                            if input != PA32QCVInput.allCases.last {
                                Divider()
                            }
                        }
                        Text("Turn off Show for inputs you do not use. At least one input remains enabled.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("Customize the label and choose an SF Symbol or emoji for each input. These names and icons appear in the switcher and menu bar.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("PA32QCV values: Thunderbolt 1 = 21, DisplayPort 1 = 15, HDMI 1 = 17. The values are sent through the official `dwc` executable.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox("This Mac") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Connection role", selection: Binding(
                            get: { preferences.role ?? .thunderbolt },
                            set: { preferences.role = $0 }
                        )) {
                            ForEach(ConnectionRole.allCases) { role in
                                Text(role.title).tag(role)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        Text("The role controls what the global toggle shortcut selects.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
            .padding(28)
        }
    }
}

private struct HardwareRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 125, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
            Spacer()
        }
    }
}
