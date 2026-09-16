import AppKit
import CoreGraphics
import Foundation

enum ScreenLockError: LocalizedError {
    case unavailable
    case accessibilityRequired
    case failed(Int32)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "macOS's Lock Screen command is unavailable on this Mac."
        case .accessibilityRequired:
            return "Enable ProArt KVM in System Settings › Privacy & Security › Accessibility to lock the screen after switching."
        case .failed(let status):
            return "macOS could not lock the screen (command exited with status \(status))."
        }
    }
}

final class ScreenLockManager {
    static let shared = ScreenLockManager()

    // This is the system helper used by the Apple menu's Lock Screen action on
    // macOS versions that still expose it.
    private let helperURLs = [
        URL(fileURLWithPath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"),
        URL(fileURLWithPath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession.bundle/Contents/MacOS/CGSession")
    ]

    private var hasSystemHelper: Bool {
        helperURLs.contains { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    @discardableResult
    func requestAccessibilityPermission() -> Bool {
        hasSystemHelper || CGRequestPostEventAccess()
    }

    @discardableResult
    func openAccessibilitySettings() -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }

    func lock() throws {
        if let helperURL = helperURLs.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) {
            try run(helperAt: helperURL)
            return
        }

        // Newer macOS versions no longer ship CGSession. The Apple menu's
        // Lock Screen action is also available as Control-Command-Q.
        guard CGPreflightPostEventAccess() else {
            throw ScreenLockError.accessibilityRequired
        }
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 12, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 12, keyDown: false) else {
            throw ScreenLockError.unavailable
        }

        let flags: CGEventFlags = [.maskControl, .maskCommand]
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func run(helperAt executableURL: URL) throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["-suspend"]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ScreenLockError.failed(process.terminationStatus)
        }
    }
}
