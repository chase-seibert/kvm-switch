import AppKit

@main
final class ProArtKVMApp: NSObject, NSApplicationDelegate {
    private let menuBarController = MenuBarController()

    static func main() {
        let application = NSApplication.shared
        let delegate = ProArtKVMApp()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMainMenu()
        menuBarController.start()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            menuBarController.showMainWindow()
        }
        return true
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About ProArt KVM", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(showPreferences), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit ProArt KVM", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let increaseText = NSMenuItem(title: "Increase Text Size", action: #selector(increaseTextSize), keyEquivalent: "+")
        increaseText.keyEquivalentModifierMask = [.command]
        increaseText.target = self
        viewMenu.addItem(increaseText)
        let decreaseText = NSMenuItem(title: "Decrease Text Size", action: #selector(decreaseTextSize), keyEquivalent: "-")
        decreaseText.keyEquivalentModifierMask = [.command]
        decreaseText.target = self
        viewMenu.addItem(decreaseText)
        let resetText = NSMenuItem(title: "Reset Text Size", action: #selector(resetTextSize), keyEquivalent: "0")
        resetText.keyEquivalentModifierMask = [.command]
        resetText.target = self
        viewMenu.addItem(resetText)
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        let closeWindow = NSMenuItem(title: "Close Window", action: #selector(closeMainWindow), keyEquivalent: "w")
        closeWindow.keyEquivalentModifierMask = [.command]
        closeWindow.target = self
        windowMenu.addItem(closeWindow)
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        let helpItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(withTitle: "ProArt KVM Help", action: #selector(showHelp), keyEquivalent: "?")
        helpItem.submenu = helpMenu
        mainMenu.addItem(helpItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func showPreferences() { menuBarController.showPreferences() }

    @objc private func closeMainWindow() { NSApp.keyWindow?.performClose(nil) }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc private func increaseTextSize() { Preferences.shared.fontScale = min(Preferences.shared.fontScale + 0.1, 1.35) }
    @objc private func decreaseTextSize() { Preferences.shared.fontScale = max(Preferences.shared.fontScale - 0.1, 0.85) }
    @objc private func resetTextSize() { Preferences.shared.fontScale = 1.0 }

    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "ProArt KVM"
        alert.informativeText = "The app uses ASUS Display Control's official dwc command-line tool. Complete onboarding to download it and verify the PA32QCV. Use the large input buttons, the menu-bar commands, or Control-Option-Command-K to switch away from this Mac."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
