import CoreGraphics
import Darwin
import Foundation
import IOKit
import IOKit.graphics
import IOKit.i2c

@_silgen_name("CGDisplayIOServicePort")
private func legacyDisplayIOServicePort(_ display: CGDirectDisplayID) -> io_service_t

// Read-only by default. A single --candidate 0xNN write is explicit so that
// hardware validation never sends a batch of unverified input values.
struct DisplayInfo {
    let id: CGDirectDisplayID
    let service: io_service_t
    let vendor: UInt32
    let product: UInt32
    let serial: UInt32?
    let name: String
}

enum ProbeError: Error, CustomStringConvertible {
    case noDisplay(String)
    case ddc(String)
    var description: String {
        switch self {
        case .noDisplay(let message), .ddc(let message): return message
        }
    }
}

func displayName(_ value: Any?) -> String {
    if let value = value as? String { return value }
    if let value = value as? [String: String] { return value.values.first ?? "External Display" }
    if let value = value as? NSDictionary { return value.allValues.first as? String ?? "External Display" }
    return "External Display"
}

func displays() -> [DisplayInfo] {
    let capacity: UInt32 = 32
    var count = capacity
    var ids = Array(repeating: CGDirectDisplayID(0), count: Int(capacity))
    _ = CGGetOnlineDisplayList(capacity, &ids, &count)
    guard count > 0 else { return [] }
    ids.removeLast(ids.count - Int(min(count, capacity)))
    return ids.compactMap { id in
        guard CGDisplayIsBuiltin(id) == 0 else { return nil }
        let service = legacyDisplayIOServicePort(id)
        let info = service == 0 ? [:] : (IODisplayCreateInfoDictionary(service, UInt32(kIODisplayOnlyPreferredName))?.takeRetainedValue() as? [String: Any] ?? [:])
        let vendor = (info[kDisplayVendorID] as? NSNumber)?.uint32Value ?? CGDisplayVendorNumber(id)
        let product = (info[kDisplayProductID] as? NSNumber)?.uint32Value ?? CGDisplayModelNumber(id)
        return DisplayInfo(
            id: id,
            service: service,
            vendor: vendor,
            product: product,
            serial: (info[kDisplaySerialNumber] as? NSNumber)?.uint32Value,
            name: info.isEmpty && vendor == 1715 && product == 12812 ? "PA32QCV" : displayName(info[kDisplayProductName])
        )
    }
}

final class DDCProbe {
    private let service: io_service_t
    private let connection: IOI2CConnectRef
    private let interface: io_service_t

    init(display: DisplayInfo) throws {
        guard display.service != 0 else {
            throw ProbeError.ddc("PA32QCV was detected by CoreGraphics, but macOS exposed no legacy I2C/DDC service for it.")
        }
        var count: IOItemCount = 0
        guard IOFBGetI2CInterfaceCount(display.service, &count) == kIOReturnSuccess else { throw ProbeError.ddc("No I2C interfaces found") }
        var interface: io_service_t = 0
        var connection: IOI2CConnectRef?
        for bus in 0..<count {
            var candidate: io_service_t = 0
            guard IOFBCopyI2CInterfaceForBus(display.service, IOOptionBits(bus), &candidate) == kIOReturnSuccess else { continue }
            if IOI2CInterfaceOpen(candidate, 0, &connection) == kIOReturnSuccess, let connection {
                interface = candidate
                self.connection = connection
                self.service = display.service
                self.interface = interface
                return
            }
            IOObjectRelease(candidate)
        }
        throw ProbeError.ddc("Could not open a DDC/CI I2C interface")
    }

    deinit {
        IOI2CInterfaceClose(connection, 0)
        IOObjectRelease(interface)
    }

    func readVCP(_ command: UInt8) throws -> UInt16 {
        let payload = [UInt8(0x51), 0x82, 0x01, command, checksum([0x51, 0x82, 0x01, command])]
        let reply = try transact(send: payload, replySize: 32)
        guard let index = reply.firstIndex(of: command), index + 5 < reply.count else { throw ProbeError.ddc("Malformed VCP response: \(hex(reply))") }
        return UInt16(reply[index + 4]) << 8 | UInt16(reply[index + 5])
    }

    func writeVCP(_ command: UInt8, _ value: UInt8) throws {
        let body = [UInt8(0x51), 0x84, 0x03, command, value]
        _ = try transact(send: body + [checksum(body)], replySize: 0)
    }

    private func transact(send: [UInt8], replySize: Int) throws -> [UInt8] {
        var send = send
        var reply = Array(repeating: UInt8(0), count: max(replySize, 1))
        var request = IOI2CRequest()
        request.sendAddress = 0x6E
        request.sendTransactionType = UInt32(kIOI2CSimpleTransactionType)
        request.sendBytes = UInt32(send.count)
        request.replyAddress = 0x6F
        request.replyTransactionType = replySize > 0 ? UInt32(kIOI2CDDCciReplyTransactionType) : UInt32(kIOI2CNoTransactionType)
        request.replyBytes = UInt32(replySize)
        let result = send.withUnsafeMutableBytes { sendBuffer in
            reply.withUnsafeMutableBytes { replyBuffer in
                request.sendBuffer = vm_address_t(UInt(bitPattern: sendBuffer.baseAddress!))
                request.replyBuffer = vm_address_t(UInt(bitPattern: replyBuffer.baseAddress!))
                return IOI2CSendRequest(connection, 0, &request)
            }
        }
        guard result == kIOReturnSuccess, request.result == kIOReturnSuccess else {
            throw ProbeError.ddc("I2C transaction failed: \(result), request result: \(request.result)")
        }
        return Array(reply.prefix(Int(request.replyBytes)))
    }
}

func checksum(_ bytes: [UInt8]) -> UInt8 { bytes.reduce(0, ^) }
func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02X", $0) }.joined(separator: " ") }

func run() throws {
    let found = displays()
    guard !found.isEmpty else { throw ProbeError.noDisplay("No external displays found.") }
    for (index, display) in found.enumerated() {
        print("Display \(index): \(display.name)")
        print("  display ID: 0x\(String(display.id, radix: 16)) (\(display.id))")
        print("  vendor ID: 0x\(String(display.vendor, radix: 16))")
        print("  product ID: 0x\(String(display.product, radix: 16))")
        print("  serial: \(display.serial.map(String.init) ?? "unavailable")")
        print("  legacy DDC service: \(display.service == 0 ? "unavailable" : "available")")
    }

    guard let target = found.first(where: {
        $0.name.localizedCaseInsensitiveContains("PA32QCV") || ($0.vendor == 1715 && $0.product == 12812)
    }) else {
        throw ProbeError.noDisplay("ASUS PA32QCV not found. Refusing to probe an unrecognized display.")
    }

    let probe = try DDCProbe(display: target)
    print("\nTarget: \(target.name), vendor 0x\(String(target.vendor, radix: 16)), product 0x\(String(target.product, radix: 16))")
    do {
        let value = try probe.readVCP(0x60)
        print("VCP 0x60 current value: 0x\(String(format: "%02X", value))")
    } catch { print("VCP 0x60 read failed: \(error)") }

    let candidateArguments = CommandLine.arguments.drop { $0 != "--candidate" }.dropFirst()
    if let candidateText = candidateArguments.first,
       let candidate = UInt8(candidateText.replacingOccurrences(of: "0x", with: "", options: .caseInsensitive), radix: 16) {
        print("Writing one explicit candidate: VCP 0x60 = 0x\(String(format: "%02X", candidate))")
        try probe.writeVCP(0x60, candidate)
        print("Write completed. Confirm the monitor input and then read VCP 0x60 again.")
    } else {
        print("\nNo writes performed.")
        print("To test one candidate after manual confirmation, run:")
        print("  ddc-probe --candidate 0x0F")
        print("Known candidates to validate one at a time: 0x0F (DisplayPort), 0x1B (common USB-C candidate).")
    }
}

do { try run() }
catch {
    fputs("ddc-probe: \(error)\n", stderr)
    exit(1)
}
