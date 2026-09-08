import CoreGraphics
import Foundation
import IOKit
import IOKit.graphics

// The SDK marks CGDisplayIOServicePort unavailable even though the native
// symbol is still present on older macOS releases. Keep the compatibility
// declaration local to this file; modern systems may return service 0.
@_silgen_name("CGDisplayIOServicePort")
private func legacyDisplayIOServicePort(_ display: CGDirectDisplayID) -> io_service_t

struct DisplayDescriptor: Identifiable, Sendable {
    let id: CGDirectDisplayID
    let vendorID: UInt32
    let productID: UInt32
    let serialNumber: UInt32?
    let name: String
    let edid: Data?
    let service: io_service_t

    var hasLegacyDDCService: Bool { service != 0 }

    var identitySummary: String {
        let serial = serialNumber.map(String.init) ?? "unknown"
        return "\(name) — display 0x\(String(id, radix: 16)), vendor 0x\(String(vendorID, radix: 16)), product 0x\(String(productID, radix: 16)), serial \(serial)"
    }
}

enum DisplayDiscoveryError: LocalizedError {
    case noDisplays
    case pa32qcvNotFound

    var errorDescription: String? {
        switch self {
        case .noDisplays: return "No external displays are connected."
        case .pa32qcvNotFound: return "PA32QCV not found"
        }
    }
}

enum DisplayDiscovery {
    static func externalDisplays() -> [DisplayDescriptor] {
        // On recent Apple Silicon systems the nil-buffer sizing form can
        // return a non-success CGError while still populating the count. Use
        // one fixed buffer and trust the populated count, which is how the
        // system currently exposes the online display list.
        let capacity: UInt32 = 32
        var displayCount = capacity
        var displayIDs = Array(repeating: CGDirectDisplayID(0), count: Int(capacity))
        _ = CGGetOnlineDisplayList(capacity, &displayIDs, &displayCount)
        guard displayCount > 0 else { return [] }
        displayIDs.removeLast(displayIDs.count - Int(min(displayCount, capacity)))

        return displayIDs.compactMap { descriptor(for: $0) }.filter { CGDisplayIsBuiltin($0.id) == 0 }
    }

    static func findPA32QCV() throws -> DisplayDescriptor {
        guard let display = externalDisplays().first(where: PA32QCVProfile.matches) else {
            throw DisplayDiscoveryError.pa32qcvNotFound
        }
        return display
    }

    private static func descriptor(for displayID: CGDirectDisplayID) -> DisplayDescriptor? {
        let service = legacyDisplayIOServicePort(displayID)
        let rawInfo = service == 0 ? nil : IODisplayCreateInfoDictionary(service, UInt32(kIODisplayOnlyPreferredName))
        let info = rawInfo?.takeRetainedValue() as? [String: Any] ?? [:]

        let vendorID = (info[kDisplayVendorID] as? NSNumber)?.uint32Value ?? CGDisplayVendorNumber(displayID)
        let productID = (info[kDisplayProductID] as? NSNumber)?.uint32Value ?? CGDisplayModelNumber(displayID)
        let serial = (info[kDisplaySerialNumber] as? NSNumber)?.uint32Value
        let name = productName(from: info[kDisplayProductName])
            ?? (PA32QCVProfile.matchesIdentity(vendorID: vendorID, productID: productID) ? "PA32QCV" : "External Display")
        let edid = (info[kIODisplayEDIDKey] as? Data) ?? (info[kIODisplayEDIDOriginalKey] as? Data)

        return DisplayDescriptor(
            id: displayID,
            vendorID: vendorID,
            productID: productID,
            serialNumber: serial,
            name: name,
            edid: edid,
            service: service
        )
    }

    private static func productName(from value: Any?) -> String? {
        if let name = value as? String { return name }
        if let names = value as? [String: String] { return names.values.first }
        if let names = value as? NSDictionary { return names.allValues.first as? String }
        return nil
    }
}

enum PA32QCVProfile {
    // These remain unset until the monitor's EDID identity is confirmed by a
    // successful DDC probe. The fallback pair below is the CoreGraphics
    // identity observed for the user's currently connected PA32QCV when the
    // legacy display service is unavailable.
    static let verifiedVendorID: UInt32? = nil
    static let verifiedProductID: UInt32? = nil
    // CoreGraphics reported this stable vendor/product pair for the user's
    // connected PA32QCV even though the legacy IOKit display service was 0.
    // It lets discovery identify the monitor on modern Apple Silicon while
    // leaving DDC availability as a separate, visible status.
    static let observedCoreGraphicsVendorID: UInt32 = 1715
    static let observedCoreGraphicsProductID: UInt32 = 12812
    static let modelName = "PA32QCV"

    static func matchesIdentity(vendorID: UInt32, productID: UInt32) -> Bool {
        if let verifiedVendorID, vendorID != verifiedVendorID { return false }
        if let verifiedProductID, productID != verifiedProductID { return false }
        return vendorID == observedCoreGraphicsVendorID && productID == observedCoreGraphicsProductID
    }

    static func matches(_ display: DisplayDescriptor) -> Bool {
        if display.name.localizedCaseInsensitiveContains(modelName) {
            if let verifiedVendorID, display.vendorID != verifiedVendorID { return false }
            if let verifiedProductID, display.productID != verifiedProductID { return false }
            return true
        }
        guard matchesIdentity(vendorID: display.vendorID, productID: display.productID) else { return false }
        if let verifiedVendorID, display.vendorID != verifiedVendorID { return false }
        if let verifiedProductID, display.productID != verifiedProductID { return false }
        return true
    }
}
