import Foundation
import IOKit
import IOKit.i2c

final class DDCController {
    enum DDCError: LocalizedError {
        case noI2CBus
        case interfaceOpen(IOReturn)
        case transaction(IOReturn)
        case malformedReply

        var errorDescription: String? {
            switch self {
            case .noI2CBus: return "No DDC/CI I2C bus is available for the PA32QCV."
            case .interfaceOpen(let result): return "Could not open the display's DDC interface (IOReturn \(result))."
            case .transaction(let result): return "The DDC/CI transaction failed (IOReturn \(result))."
            case .malformedReply: return "The PA32QCV returned an unreadable DDC/CI response."
            }
        }
    }

    private let interfaceService: io_service_t
    private let connection: IOI2CConnectRef

    init(display: DisplayDescriptor) throws {
        guard display.service != 0 else { throw DDCError.noI2CBus }
        var busCount: IOItemCount = 0
        let countResult = IOFBGetI2CInterfaceCount(display.service, &busCount)
        guard countResult == kIOReturnSuccess, busCount > 0 else { throw DDCError.noI2CBus }

        var selectedInterface: io_service_t = 0
        var selectedConnection: IOI2CConnectRef?

        for bus in 0..<busCount {
            var candidate: io_service_t = 0
            guard IOFBCopyI2CInterfaceForBus(display.service, IOOptionBits(bus), &candidate) == kIOReturnSuccess else { continue }

            var connection: IOI2CConnectRef?
            let openResult = IOI2CInterfaceOpen(candidate, 0, &connection)
            if openResult == kIOReturnSuccess, let connection {
                selectedInterface = candidate
                selectedConnection = connection
                break
            }
            IOObjectRelease(candidate)
        }

        guard let selectedConnection else { throw DDCError.interfaceOpen(kIOReturnError) }
        interfaceService = selectedInterface
        connection = selectedConnection
    }

    deinit {
        IOI2CInterfaceClose(connection, 0)
        IOObjectRelease(interfaceService)
    }

    func writeVCP(command: UInt8, value: UInt8) throws {
        var bytes: [UInt8] = [0x51, 0x84, 0x03, command, value]
        bytes.append(checksum(bytes))
        _ = try perform(send: bytes, replyCapacity: 0)
    }

    func readVCP(command: UInt8) throws -> UInt16 {
        var bytes: [UInt8] = [0x51, 0x82, 0x01, command]
        bytes.append(checksum(bytes))
        let reply = try perform(send: bytes, replyCapacity: 32)

        // A VCP response normally contains: 0x02, length, 0x00, command,
        // type, max-high, max-low, current-high, current-low, checksum.
        guard let commandIndex = reply.firstIndex(of: command), commandIndex + 5 < reply.count else {
            throw DDCError.malformedReply
        }
        let currentHighIndex = commandIndex + 4
        let currentLowIndex = commandIndex + 5
        return UInt16(reply[currentHighIndex]) << 8 | UInt16(reply[currentLowIndex])
    }

    private func checksum(_ bytes: [UInt8]) -> UInt8 {
        bytes.reduce(0, ^)
    }

    private func perform(send bytes: [UInt8], replyCapacity: Int) throws -> [UInt8] {
        var sendBytes = bytes
        var replyBytes = Array(repeating: UInt8(0), count: max(replyCapacity, 1))
        var request = IOI2CRequest()
        request.sendAddress = 0x6E
        request.sendTransactionType = UInt32(kIOI2CSimpleTransactionType)
        request.sendBytes = UInt32(sendBytes.count)
        request.replyAddress = 0x6F
        request.replyTransactionType = replyCapacity > 0 ? UInt32(kIOI2CDDCciReplyTransactionType) : UInt32(kIOI2CNoTransactionType)
        request.replyBytes = UInt32(replyCapacity)

        let sendResult = sendBytes.withUnsafeMutableBytes { sendBuffer in
            replyBytes.withUnsafeMutableBytes { replyBuffer in
                request.sendBuffer = vm_address_t(UInt(bitPattern: sendBuffer.baseAddress!))
                request.replyBuffer = vm_address_t(UInt(bitPattern: replyBuffer.baseAddress!))
                return IOI2CSendRequest(connection, 0, &request)
            }
        }

        guard sendResult == kIOReturnSuccess, request.result == kIOReturnSuccess else {
            throw DDCError.transaction(sendResult == kIOReturnSuccess ? request.result : sendResult)
        }
        return Array(replyBytes.prefix(Int(request.replyBytes)))
    }
}
