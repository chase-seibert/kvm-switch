import Foundation

struct ASUSMonitor: Identifiable, Equatable, Sendable {
    let id: Int
    let model: String
    let serialNumber: String
    let deviceID: Int

    var isPA32QCV: Bool {
        model.localizedCaseInsensitiveContains("PA32QCV")
    }
}

struct ASUSCLIResult: Sendable {
    let standardOutput: String
    let standardError: String
    let status: Int32
}

enum ASUSCLIError: LocalizedError {
    case notInstalled
    case downloadFailed(String)
    case archiveExtractionFailed(String)
    case binaryNotFound
    case commandFailed(String)
    case pa32qcvNotFound
    case invalidOutput(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "The ASUS Display Control CLI is not installed yet."
        case .downloadFailed(let message):
            return "Could not download the ASUS Display Control CLI: \(message)"
        case .archiveExtractionFailed(let message):
            return "Could not unpack the ASUS Display Control CLI: \(message)"
        case .binaryNotFound:
            return "The downloaded archive did not contain the ASUS `dwc` executable."
        case .commandFailed(let message):
            return "The ASUS Display Control command failed: \(message)"
        case .pa32qcvNotFound:
            return "The ASUS CLI is installed, but it did not find a PA32QCV."
        case .invalidOutput(let message):
            return "The ASUS CLI returned unexpected output: \(message)"
        }
    }
}

final class ASUSCLIManager {
    static let shared = ASUSCLIManager()

    // This is the official macOS asset linked by ASUS's public CLI repository.
    static let downloadURL = URL(string: "https://github.com/ASUS-Display/asus-display-control/raw/main/cli/macOS/dwc_mac.zip")!
    static let repositoryURL = URL(string: "https://github.com/ASUS-Display/asus-display-control")!

    private let fileManager = FileManager.default
    private let applicationSupportFolderName = "ASUS Display Control"

    var installDirectoryURL: URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return applicationSupport.appendingPathComponent("ProArt KVM", isDirectory: true)
            .appendingPathComponent(applicationSupportFolderName, isDirectory: true)
    }

    var executableURL: URL {
        installDirectoryURL.appendingPathComponent("dwc")
    }

    var libraryURL: URL {
        installDirectoryURL.appendingPathComponent("libVCPLibrary.dylib")
    }

    var isInstalled: Bool {
        fileManager.isExecutableFile(atPath: executableURL.path)
            && fileManager.isReadableFile(atPath: libraryURL.path)
    }

    func installedVersion() throws -> String? {
        guard isInstalled else { return nil }
        let result = try runSynchronously(arguments: ["--version"])
        let value = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func install() async throws -> String? {
        let (archiveData, response): (Data, URLResponse)
        do {
            (archiveData, response) = try await URLSession.shared.data(from: Self.downloadURL)
        } catch {
            throw ASUSCLIError.downloadFailed(error.localizedDescription)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw ASUSCLIError.downloadFailed("HTTP \(httpResponse.statusCode)")
        }

        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("ProArtKVM-CLI-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = temporaryDirectory.appendingPathComponent("dwc_mac.zip")
        let extractionURL = temporaryDirectory.appendingPathComponent("extracted", isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryDirectory) }

        do {
            try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
            try archiveData.write(to: archiveURL, options: .atomic)
            try fileManager.createDirectory(at: extractionURL, withIntermediateDirectories: true)
            _ = try runProcess(
                executableURL: URL(fileURLWithPath: "/usr/bin/ditto"),
                arguments: ["-x", "-k", archiveURL.path, extractionURL.path]
            )

            guard let downloadedExecutable = findExecutable(named: "dwc", inside: extractionURL) else {
                throw ASUSCLIError.binaryNotFound
            }
            guard let downloadedLibrary = findExecutable(named: "libVCPLibrary.dylib", inside: extractionURL) else {
                throw ASUSCLIError.archiveExtractionFailed("The archive did not contain libVCPLibrary.dylib required by dwc.")
            }

            try fileManager.createDirectory(at: installDirectoryURL, withIntermediateDirectories: true)
            let stagingDirectory = installDirectoryURL.appendingPathComponent("staging-(UUID().uuidString)", isDirectory: true)
            try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: stagingDirectory) }

            let stagedExecutable = stagingDirectory.appendingPathComponent("dwc")
            let stagedLibrary = stagingDirectory.appendingPathComponent("libVCPLibrary.dylib")
            try fileManager.copyItem(at: downloadedExecutable, to: stagedExecutable)
            try fileManager.copyItem(at: downloadedLibrary, to: stagedLibrary)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stagedExecutable.path)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stagedLibrary.path)

            if fileManager.fileExists(atPath: executableURL.path) {
                try fileManager.removeItem(at: executableURL)
            }
            if fileManager.fileExists(atPath: libraryURL.path) {
                try fileManager.removeItem(at: libraryURL)
            }
            try fileManager.moveItem(at: stagedExecutable, to: executableURL)
            try fileManager.moveItem(at: stagedLibrary, to: libraryURL)
        } catch let error as ASUSCLIError {
            throw error
        } catch {
            throw ASUSCLIError.archiveExtractionFailed(error.localizedDescription)
        }

        return try installedVersion()
    }

    func listMonitors() throws -> [ASUSMonitor] {
        let result = try runSynchronously(arguments: ["list"])
        return try parseMonitors(from: result.standardOutput)
    }

    func currentInputValue(for monitor: ASUSMonitor) throws -> Int {
        let result = try runSynchronously(arguments: ["get", "InputSource", "--id", String(monitor.id)])
        guard let value = firstInteger(in: result.standardOutput) else {
            throw ASUSCLIError.invalidOutput(result.standardOutput)
        }
        return value
    }

    func setInputValue(_ value: Int, for monitor: ASUSMonitor) throws {
        _ = try runSynchronously(arguments: ["set", "InputSource", String(value), "--id", String(monitor.id)])
    }

    func setVCPValue(_ value: UInt16, code: UInt8, for monitor: ASUSMonitor) throws {
        _ = try runSynchronously(arguments: [
            "setvcp",
            String(format: "0x%02X", code),
            String(value),
            "--id",
            String(monitor.id)
        ])
    }

    func listMonitorsAsync() async throws -> [ASUSMonitor] {
        try await runOffMain { try self.listMonitors() }
    }

    func installedVersionAsync() async throws -> String? {
        try await runOffMain { try self.installedVersion() }
    }

    private func runOffMain<T: Sendable>(_ operation: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try operation())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func runSynchronously(arguments: [String]) throws -> ASUSCLIResult {
        guard isInstalled else { throw ASUSCLIError.notInstalled }
        return try runProcess(executableURL: executableURL, arguments: arguments)
    }

    private func runProcess(executableURL: URL, arguments: [String]) throws -> ASUSCLIResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw ASUSCLIError.commandFailed(error.localizedDescription)
        }
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let result = ASUSCLIResult(standardOutput: output, standardError: error, status: process.terminationStatus)
        guard process.terminationStatus == 0 else {
            let message = error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? output.trimmingCharacters(in: .whitespacesAndNewlines)
                : error.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ASUSCLIError.commandFailed(message.isEmpty ? "exit status \(process.terminationStatus)" : message)
        }
        return result
    }

    private func findExecutable(named name: String, inside directory: URL) -> URL? {
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return nil
        }
        for case let url as URL in enumerator {
            guard url.lastPathComponent == name,
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            return url
        }
        return nil
    }

    private func parseMonitors(from output: String) throws -> [ASUSMonitor] {
        var monitors: [ASUSMonitor] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let columns = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard columns.count >= 4,
                  let id = Int(columns[0]),
                  let deviceID = Int(columns[3]),
                  id > 0 else { continue }
            monitors.append(ASUSMonitor(
                id: id,
                model: String(columns[1]),
                serialNumber: String(columns[2]),
                deviceID: deviceID
            ))
        }
        return monitors
    }

    private func firstInteger(in output: String) -> Int? {
        output.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" })
            .compactMap { Int($0) }
            .first
    }
}
