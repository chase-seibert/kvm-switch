import Foundation

enum PA32QCVInput: String, CaseIterable, Identifiable, Sendable {
    case thunderbolt
    case displayPort
    case hdmi

    var id: String { rawValue }

    // These are the PA32QCV InputSource values documented by ASUS's CLI.
    var cliValue: Int {
        switch self {
        case .displayPort: return 15
        case .hdmi: return 17
        case .thunderbolt: return 21
        }
    }

    var title: String {
        switch self {
        case .thunderbolt: return "Thunderbolt 1"
        case .displayPort: return "DisplayPort 1"
        case .hdmi: return "HDMI 1"
        }
    }

    var shortTitle: String {
        switch self {
        case .thunderbolt: return "Thunderbolt"
        case .displayPort: return "DisplayPort"
        case .hdmi: return "HDMI"
        }
    }

    var systemImage: String {
        switch self {
        case .thunderbolt: return "bolt.horizontal.circle"
        case .displayPort: return "display"
        case .hdmi: return "rectangle.connected.to.line.below"
        }
    }

    var defaultIconChoice: InputIconChoice {
        switch self {
        case .thunderbolt: return .bolt
        case .displayPort: return .display
        case .hdmi: return .connectedDisplay
        }
    }

    init?(cliValue: Int) {
        switch cliValue {
        case 15: self = .displayPort
        case 17: self = .hdmi
        case 21: self = .thunderbolt
        default: return nil
        }
    }
}

enum MonitorError: LocalizedError {
    case cliNotInstalled
    case pa32qcvNotFound

    var errorDescription: String? {
        switch self {
        case .cliNotInstalled:
            return "Install the ASUS Display Control CLI in Settings before switching."
        case .pa32qcvNotFound:
            return "The ASUS CLI did not find a PA32QCV. Check the monitor connection and refresh."
        }
    }
}

final class PA32QCVController {
    private let cli: ASUSCLIManager

    init(cli: ASUSCLIManager = .shared) {
        self.cli = cli
    }

    func findPA32QCV() throws -> ASUSMonitor {
        guard cli.isInstalled else { throw MonitorError.cliNotInstalled }
        guard let monitor = try cli.listMonitors().first(where: { $0.isPA32QCV }) else {
            throw MonitorError.pa32qcvNotFound
        }
        return monitor
    }

    func currentInput(for monitor: ASUSMonitor) throws -> PA32QCVInput? {
        PA32QCVInput(cliValue: try cli.currentInputValue(for: monitor))
    }

    func switchTo(_ input: PA32QCVInput, monitor: ASUSMonitor? = nil) throws {
        let target: ASUSMonitor
        if let monitor {
            target = monitor
        } else {
            target = try findPA32QCV()
        }
        try cli.setInputValue(input.cliValue, for: target)
    }
}
