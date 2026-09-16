import AppKit
import UserNotifications

final class MenuBarController: NSObject {
    private let preferences = Preferences.shared
    private let loginItem = LoginItemManager()
    private let cli = ASUSCLIManager.shared
    private let monitor = PA32QCVController()
    private let screenLock = ScreenLockManager.shared
    private var mainWindow: MainWindowController!
    private var statusItem: NSStatusItem!
    private var hotKeyController: HotKeyController!
    private var isConnected = false

    func start() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(systemSymbolName: "arrow.left.arrow.right.circle", accessibilityDescription: "ProArt KVM") {
            statusItem.button?.image = image
        } else {
            statusItem.button?.title = "KVM"
        }
        statusItem.button?.setAccessibilityLabel("ProArt KVM")
        statusItem.button?.toolTip = "ProArt KVM"
        rebuildMenu()

        mainWindow = MainWindowController(
            preferences: preferences,
            loginItem: loginItem,
            switchAction: { [weak self] input in self?.performSwitch(to: input) },
            refreshAction: { [weak self] in self?.synchronize() },
            installAction: { [weak self] in self?.installCLI() },
            finishSetupAction: { [weak self] in self?.finishSetup() },
            requestScreenLockPermissionAction: { [weak self] in self?.requestScreenLockPermission() },
            openScreenLockSettingsAction: { [weak self] in self?.openScreenLockSettings() },
            testScreenLockAction: { [weak self] in self?.testScreenLock() }
        )

        NotificationCenter.default.addObserver(forName: .proArtKVMPreferencesChanged, object: preferences, queue: .main) { [weak self] _ in
            self?.rebuildMenu()
        }

        hotKeyController = HotKeyController { [weak self] in self?.switchToOtherMac() }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.synchronize() }
        if !preferences.startMinimized {
            showMainWindow()
        }
    }

    @objc func showPreferences() {
        mainWindow.showSettings()
    }

    @objc private func openApp() {
        showMainWindow()
    }

    func showMainWindow() {
        guard let mainWindow else { return }
        mainWindow.show()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let cliReady = cli.isInstalled
        if preferences.isInputEnabled(.thunderbolt) {
            let thunderboltItem = item("Switch to \(preferences.displayName(for: .thunderbolt))", action: #selector(switchToThunderbolt))
            thunderboltItem.isEnabled = cliReady && isConnected
            menu.addItem(thunderboltItem)
        }
        if preferences.isInputEnabled(.displayPort) {
            let displayPortItem = item("Switch to \(preferences.displayName(for: .displayPort))", action: #selector(switchToDisplayPort))
            displayPortItem.isEnabled = cliReady && isConnected
            menu.addItem(displayPortItem)
        }
        if preferences.isInputEnabled(.hdmi) {
            let hdmiItem = item("Switch to \(preferences.displayName(for: .hdmi))", action: #selector(switchToHDMI))
            hdmiItem.isEnabled = cliReady && isConnected
            menu.addItem(hdmiItem)
        }
        let toggleItem = item("Toggle KVM\t⌃⌥⌘K", action: #selector(switchToOtherMac))
        toggleItem.isEnabled = cliReady && isConnected && preferences.role != nil
            && preferences.role.map { preferences.isInputEnabled($0.otherInput) } == true
        menu.addItem(toggleItem)
        menu.addItem(.separator())

        let roleTitle = preferences.role.map { "This Mac: \($0.title)" } ?? "This Mac: Choose connection…"
        let roleItem = NSMenuItem(title: roleTitle, action: #selector(showPreferences), keyEquivalent: "")
        roleItem.target = self
        menu.addItem(roleItem)
        let statusTitle: String
        if !cliReady { statusTitle = "ASUS CLI: Setup required" }
        else { statusTitle = isConnected ? "PA32QCV: Connected" : "PA32QCV: Checking…" }
        let statusMenuItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(item("Open App", action: #selector(openApp)))
        menu.addItem(item("Settings…", action: #selector(showPreferences)))
        menu.addItem(item("Quit ProArt KVM", action: #selector(quit)))
        statusItem.menu = menu
    }

    private func item(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func synchronize() {
        let cliInstalled = cli.isInstalled
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var foundMonitor: ASUSMonitor?
            var currentInput: PA32QCVInput?
            var currentInputValue: Int?
            var version: String?
            var errorMessage: String?

            if cliInstalled {
                version = try? cli.installedVersion()
                do {
                    foundMonitor = try monitor.findPA32QCV()
                } catch {
                    errorMessage = error.localizedDescription
                }
                if let foundMonitor {
                    do {
                        currentInputValue = try cli.currentInputValue(for: foundMonitor)
                        currentInput = PA32QCVInput(cliValue: currentInputValue ?? -1)
                    } catch {
                        errorMessage = "PA32QCV found, but the CLI could not read the current input (\(error.localizedDescription)). Direct input switches remain available."
                    }
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isConnected = foundMonitor != nil
                self.rebuildMenu()
                self.mainWindow.update(
                    monitor: foundMonitor,
                    currentInput: currentInput,
                    currentInputValue: currentInputValue,
                    cliInstalled: cliInstalled,
                    cliVersion: version,
                    errorMessage: errorMessage
                )
            }
        }
    }

    private func installCLI() {
        mainWindow.setInstalling(true, message: "Downloading the official ASUS Display Control CLI…")
        Task { [weak self] in
            guard let self else { return }
            do {
                let version = try await cli.install()
                mainWindow.setInstalling(false, message: "ASUS Display Control installed\(version.map { " (\($0))" } ?? "").")
                synchronize()
            } catch {
                mainWindow.setInstalling(false, message: nil)
                mainWindow.setError(error.localizedDescription)
            }
        }
    }

    private func finishSetup() {
        guard cli.isInstalled else {
            mainWindow.setError("Download the ASUS Display Control CLI before finishing setup.")
            return
        }
        guard isConnected else {
            mainWindow.setError("The CLI is installed, but the PA32QCV has not been discovered yet.")
            return
        }
        preferences.onboardingCompleted = true
        showMainWindow()
        synchronize()
    }

    @objc private func switchToOtherMac() {
        guard let role = preferences.role else {
            showPreferences()
            return
        }
        performSwitch(to: role.otherInput)
    }

    @objc private func switchToThunderbolt() { performSwitch(to: .thunderbolt) }
    @objc private func switchToDisplayPort() { performSwitch(to: .displayPort) }
    @objc private func switchToHDMI() { performSwitch(to: .hdmi) }

    private func performSwitch(to input: PA32QCVInput) {
        guard cli.isInstalled else {
            showPreferences()
            return
        }
        let lockScreenAfterSwitch = preferences.lockScreenAfterSwitch
        mainWindow.setBusy(true)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let target = try monitor.findPA32QCV()
                try monitor.switchTo(input, monitor: target)
                if lockScreenAfterSwitch {
                    try screenLock.lock(using: preferences.screenLockShortcut)
                }
                DispatchQueue.main.async { [weak self] in
                    self?.mainWindow.setBusy(false)
                    self?.isConnected = true
                    self?.rebuildMenu()
                    self?.synchronize()
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.mainWindow.setBusy(false)
                    if let screenLockError = error as? ScreenLockError {
                        self?.mainWindow.setScreenLockError(screenLockError.localizedDescription)
                    } else {
                        self?.mainWindow.setError(error.localizedDescription)
                    }
                    self?.present(error: error)
                }
            }
        }
    }

    private func requestScreenLockPermission() {
        mainWindow.setScreenLockStatus(nil)
        mainWindow.setScreenLockError(nil)
        if screenLock.requestAccessibilityPermission() {
            mainWindow.setScreenLockStatus("Accessibility permission is available. Test Lock Screen to verify it.")
        } else {
            mainWindow.setScreenLockError("Allow ProArt KVM in System Settings › Privacy & Security › Accessibility, then test Lock Screen.")
        }
    }

    private func openScreenLockSettings() {
        mainWindow.setScreenLockStatus(nil)
        if !screenLock.openAccessibilitySettings() {
            mainWindow.setScreenLockError("Could not open Accessibility settings. Open System Settings › Privacy & Security › Accessibility manually.")
        }
    }

    private func testScreenLock() {
        mainWindow.setScreenLockStatus(nil)
        mainWindow.setScreenLockError(nil)
        mainWindow.setBusy(true)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                try screenLock.lock(using: preferences.screenLockShortcut)
                DispatchQueue.main.async { [weak self] in
                    self?.mainWindow.setBusy(false)
                    self?.mainWindow.setScreenLockStatus("Lock Screen command sent.")
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.mainWindow.setBusy(false)
                    self?.mainWindow.setScreenLockError(error.localizedDescription)
                    self?.present(error: error)
                }
            }
        }
    }

    private func present(error: Error) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "ProArt KVM"
            content.body = error.localizedDescription
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
