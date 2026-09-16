import AppKit
import ServiceManagement
import SwiftUI

extension Notification.Name {
    static let proArtKVMPreferencesChanged = Notification.Name("ProArtKVMPreferencesChanged")
}

enum ConnectionRole: String, CaseIterable, Identifiable {
    case thunderbolt
    case displayPort

    var id: String { rawValue }
    var title: String { self == .thunderbolt ? "Thunderbolt" : "DisplayPort" }
    var otherInput: PA32QCVInput { self == .thunderbolt ? .displayPort : .thunderbolt }
}

enum ScreenLockShortcut: String, CaseIterable, Identifiable {
    case controlCommandQ = "control-command-q"
    case controlCommandL = "control-command-l"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .controlCommandQ: return "Control-Command-Q"
        case .controlCommandL: return "Control-Command-L"
        }
    }

    var virtualKey: UInt16 {
        switch self {
        case .controlCommandQ: return 12
        case .controlCommandL: return 37
        }
    }
}

enum InputIconChoice: String, CaseIterable, Identifiable, Codable {
    case bolt = "sf:bolt.horizontal.circle"
    case display = "sf:display"
    case connectedDisplay = "sf:rectangle.connected.to.line.below"
    case keyboard = "sf:keyboard"
    case laptop = "emoji:💻"
    case desktop = "emoji:🖥️"
    case personAtComputer = "emoji:🧑‍💻"
    case office = "emoji:🏢"
    case star = "sf:star"
    case gameController = "sf:gamecontroller"
    case globe = "sf:globe"
    case house = "sf:house"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bolt: return "Bolt"
        case .display: return "Display"
        case .connectedDisplay: return "Connected display"
        case .keyboard: return "Keyboard"
        case .laptop: return "Laptop"
        case .desktop: return "Desktop"
        case .personAtComputer: return "Person at computer"
        case .office: return "Office"
        case .star: return "Star"
        case .gameController: return "Game controller"
        case .globe: return "Globe"
        case .house: return "Home"
        }
    }

    var systemImage: String? {
        rawValue.hasPrefix("sf:") ? String(rawValue.dropFirst(3)) : nil
    }

    var emoji: String? {
        rawValue.hasPrefix("emoji:") ? String(rawValue.dropFirst(6)) : nil
    }
}

struct InputCustomization: Codable, Equatable {
    var name: String
    var icon: InputIconChoice.RawValue

    static func `default`(for input: PA32QCVInput) -> InputCustomization {
        InputCustomization(name: input.shortTitle, icon: input.defaultIconChoice.rawValue)
    }
}

final class LoginItemManager: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var errorMessage: String?

    init() {
        refresh()
    }

    var statusDescription: String {
        if requiresApproval {
            return "Approval required in System Settings › General › Login Items."
        }
        return isEnabled ? "ProArt KVM will open when you log in." : "ProArt KVM will not open automatically."
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled || status == .requiresApproval
        requiresApproval = status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
        } catch {
            refresh()
            errorMessage = "Could not update the login item: \(error.localizedDescription)"
        }
    }
}

final class Preferences: ObservableObject {
    static let shared = Preferences()

    @Published var role: ConnectionRole? { didSet { defaults.set(role?.rawValue, forKey: Keys.role); notifyChange() } }
    @Published var onboardingCompleted: Bool { didSet { defaults.set(onboardingCompleted, forKey: Keys.onboardingCompleted); notifyChange() } }
    @Published var enabledInputs: Set<PA32QCVInput> { didSet { saveEnabledInputs(); notifyChange() } }
    @Published var inputCustomizations: [String: InputCustomization] { didSet { saveInputCustomizations(); notifyChange() } }
    @Published var fontScale: Double { didSet { defaults.set(fontScale, forKey: Keys.fontScale); notifyChange() } }
    @Published var lockScreenAfterSwitch: Bool { didSet { defaults.set(lockScreenAfterSwitch, forKey: Keys.lockScreenAfterSwitch); notifyChange() } }
    @Published var screenLockShortcut: ScreenLockShortcut { didSet { defaults.set(screenLockShortcut.rawValue, forKey: Keys.screenLockShortcut); notifyChange() } }
    @Published var startMinimized: Bool { didSet { defaults.set(startMinimized, forKey: Keys.startMinimized); notifyChange() } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        role = defaults.string(forKey: Keys.role).flatMap(ConnectionRole.init(rawValue:))
        onboardingCompleted = defaults.bool(forKey: Keys.onboardingCompleted)
        if let savedInputs = defaults.array(forKey: Keys.enabledInputs) as? [String] {
            enabledInputs = Set(savedInputs.compactMap(PA32QCVInput.init(rawValue:)))
        } else {
            enabledInputs = Set(PA32QCVInput.allCases)
        }
        if let data = defaults.data(forKey: Keys.inputCustomizations),
           let savedCustomizations = try? JSONDecoder().decode([String: InputCustomization].self, from: data) {
            inputCustomizations = savedCustomizations
        } else {
            inputCustomizations = [:]
        }
        let storedScale = defaults.double(forKey: Keys.fontScale)
        fontScale = storedScale == 0 ? 1.0 : min(max(storedScale, 0.85), 1.35)
        lockScreenAfterSwitch = defaults.bool(forKey: Keys.lockScreenAfterSwitch)
        screenLockShortcut = defaults.string(forKey: Keys.screenLockShortcut).flatMap(ScreenLockShortcut.init(rawValue:)) ?? .controlCommandQ
        startMinimized = defaults.bool(forKey: Keys.startMinimized)
    }

    func isInputEnabled(_ input: PA32QCVInput) -> Bool {
        enabledInputs.contains(input)
    }

    func setInputEnabled(_ input: PA32QCVInput, enabled: Bool) {
        if enabled {
            enabledInputs.insert(input)
        } else if enabledInputs.count > 1 {
            enabledInputs.remove(input)
        }
    }

    func customization(for input: PA32QCVInput) -> InputCustomization {
        inputCustomizations[input.rawValue] ?? .default(for: input)
    }

    func displayName(for input: PA32QCVInput) -> String {
        customization(for: input).name
    }

    func iconChoice(for input: PA32QCVInput) -> InputIconChoice {
        let storedIcon = customization(for: input).icon
        return InputIconChoice(rawValue: storedIcon) ?? input.defaultIconChoice
    }

    func setCustomization(_ customization: InputCustomization, for input: PA32QCVInput) {
        var updated = inputCustomizations
        let trimmedName = customization.name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated[input.rawValue] = InputCustomization(
            name: trimmedName.isEmpty ? InputCustomization.default(for: input).name : trimmedName,
            icon: InputIconChoice(rawValue: customization.icon)?.rawValue ?? input.defaultIconChoice.rawValue
        )
        inputCustomizations = updated
    }

    private func saveEnabledInputs() {
        defaults.set(enabledInputs.map(\.rawValue).sorted(), forKey: Keys.enabledInputs)
    }

    private func saveInputCustomizations() {
        guard let data = try? JSONEncoder().encode(inputCustomizations) else { return }
        defaults.set(data, forKey: Keys.inputCustomizations)
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .proArtKVMPreferencesChanged, object: self)
    }

    private enum Keys {
        static let role = "connectionRole"
        static let onboardingCompleted = "onboardingCompleted"
        static let enabledInputs = "enabledInputs"
        static let inputCustomizations = "inputCustomizations"
        static let fontScale = "fontScale"
        static let lockScreenAfterSwitch = "lockScreenAfterSwitch"
        static let screenLockShortcut = "screenLockShortcut"
        static let startMinimized = "startMinimized"
    }
}
