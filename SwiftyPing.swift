//
//  https://github.com/samiyr/SwiftyPing
//
//  SwiftyPing.swift
//  SwiftyPing
//
//  Created by Sami Yrjänheikki on 6.8.2018.
//  Copyright © 2018 Sami Yrjänheikki. All rights reserved.
//

public typealias Observer = ((_ ping: SwiftyPing, _ response: PingResponse) -> Void)
public typealias ErrorClosure = ((_ ping: SwiftyPing, _ error: NSError) -> Void)

// MARK: SwiftyPing

public class SwiftyPing: NSObject {
    public enum PingError: Error {
        case hostLookup
        case hostLookupUnknown
        case addressLookup
        case hostNotFound
    }

    var host: String
    var ip: String
    var configuration: PingConfiguration

    public var observer: Observer?

    var errorClosure: ErrorClosure?

    var identifier: UInt32

    private var hasScheduledNextPing = false
    private var ipv4address: Data?
    private var socket: CFSocket?
    private var socketSource: CFRunLoopSource?

    private var isPinging = false
    private var currentSequenceNumber: UInt64 = 0
    private var currentStartDate: Date?

    private var timeoutBlock: (() -> Void)?

    private var currentQueue: DispatchQueue?

    private let serial = DispatchQueue(label: "ping serial", qos: .userInteractive, attributes: [], autoreleaseFrequency: .workItem, target: nil)

    func socketCallback(socket: CFSocket, type: CFSocketCallBackType, address: CFData, data: UnsafeRawPointer, info: UnsafeMutableRawPointer) {
        var info = info
        let ping = withUnsafePointer(to: &info) { (temp) in
            return unsafeBitCast(temp, to: SwiftyPing.self)
        }

        if (type as CFSocketCallBackType) == CFSocketCallBackType.dataCallBack {
            let fData = data.assumingMemoryBound(to: UInt8.self)
            let bytes = UnsafeBufferPointer<UInt8>(start: fData, count: MemoryLayout<UInt8>.size)
            let cfdata = Data(buffer: bytes)
            ping.socket(socket: socket, didReadData: cfdata)
        }
    }

    class func getIPv4AddressFromHost(host: String) throws -> Data {
        var streamError = CFStreamError()
        let cfhost = CFHostCreateWithName(nil, host as CFString).takeRetainedValue()
        let status = CFHostStartInfoResolution(cfhost, .addresses, &streamError)

        var data: Data?
        guard status else {
            if Int32(streamError.domain) == kCFStreamErrorDomainNetDB {
                throw PingError.hostLookup
            } else {
                throw PingError.hostLookupUnknown
            }
        }
        var success: DarwinBoolean = false
        guard let addresses = CFHostGetAddressing(cfhost, &success)?.takeUnretainedValue() as? [Data] else {
            throw PingError.addressLookup
        }

        for address in addresses {
            let addrin = address.socketAddress
            if address.count >= MemoryLayout<sockaddr>.size && addrin.sa_family == UInt8(AF_INET) {
                data = address
                break
            }
        }
        guard let trueData = data, !trueData.isEmpty else {
            throw PingError.hostNotFound
        }

        return trueData
    }

    public init(host: String, ipv4Address: Data, configuration: PingConfiguration, queue: DispatchQueue) {
        self.host = host
        self.ipv4address = ipv4Address
        self.configuration = configuration
        self.identifier = UInt32(arc4random_uniform(UInt32(UInt16.max)))
        self.currentQueue = queue

        let socketAddress = ipv4Address.socketAddressInternet
        self.ip = String(cString: inet_ntoa(socketAddress.sin_addr), encoding: String.Encoding.ascii) ?? ""

        super.init()

        var context = CFSocketContext(version: 0,
                info: Unmanaged.passRetained(self).toOpaque(),
                retain: nil,
                release: nil,
                copyDescription: nil)

        self.socket = CFSocketCreate(kCFAllocatorDefault, AF_INET, SOCK_DGRAM, IPPROTO_ICMP, CFSocketCallBackType.dataCallBack.rawValue, { socket, type, address, data, info in
            guard let socket = socket, let info = info else {
                return
            }
            let ping: SwiftyPing = Unmanaged.fromOpaque(info).takeUnretainedValue()
            if (type as CFSocketCallBackType) == CFSocketCallBackType.dataCallBack {
                let fData = data?.assumingMemoryBound(to: UInt8.self)
                let bytes = UnsafeBufferPointer<UInt8>(start: fData, count: MemoryLayout<UInt8>.size)
                let cfdata = Data(buffer: bytes)
                ping.socket(socket: socket, didReadData: cfdata)
            }

        }, &context)

        socketSource = CFSocketCreateRunLoopSource(nil, socket, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), socketSource, .commonModes)
    }

    public convenience init(ipv4Address: String, config configuration: PingConfiguration, queue: DispatchQueue) {
        var socketAddress = sockaddr_in()
        memset(&socketAddress, 0, MemoryLayout<sockaddr_in>.size)

        socketAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        socketAddress.sin_family = UInt8(AF_INET)
        socketAddress.sin_port = 0
        socketAddress.sin_addr.s_addr = inet_addr(ipv4Address.cString(using: String.Encoding.utf8))
        let data = NSData(bytes: &socketAddress, length: MemoryLayout<sockaddr_in>.size)

        self.init(host: ipv4Address, ipv4Address: data as Data, configuration: configuration, queue: queue)
    }

    public convenience init?(host: String, configuration: PingConfiguration, queue: DispatchQueue) {
        let result = try? SwiftyPing.getIPv4AddressFromHost(host: host)
        if let address = result {
            self.init(host: host, ipv4Address: address, configuration: configuration, queue: queue)
        } else {
            return nil
        }
    }

    deinit {
        CFRunLoopSourceInvalidate(socketSource)
        socketSource = nil
        socket = nil
    }

    public func start() {
        serial.sync {
            if !self.isPinging {
                self.isPinging = true
                self.currentSequenceNumber = 0
                self.currentStartDate = nil
            }
        }
        currentQueue?.async {
            self.sendPing()
        }
    }

    public func stop() {
        serial.sync {
            self.isPinging = false
            self.currentSequenceNumber = 0
            self.currentStartDate = nil
            self.timeoutBlock = nil
        }
    }

    func scheduleNextPing() {
        serial.sync {
            if self.hasScheduledNextPing {
                return
            }

            self.hasScheduledNextPing = true
            self.timeoutBlock = nil
            self.currentQueue?.asyncAfter(deadline: .now() + self.configuration.pingInterval, execute: {
                self.hasScheduledNextPing = false
                self.sendPing()
            })
        }
    }

    func socket(socket: CFSocket, didReadData data: Data?) {
        let ipHeaderData: NSData? = nil
        //        var ipData:NSData?
        //        var icmpHeaderData:NSData?
        //        var icmpData:NSData?

        let extractIPAddressBlock: () -> String? = {
            if ipHeaderData == nil {
                return nil
            }
            guard var bytes = ipHeaderData?.bytes else {
                return nil
            }
            let ipHeader: IPHeader = withUnsafePointer(to: &bytes) { (temp) in
                return unsafeBitCast(temp, to: IPHeader.self)
            }

            let sourceAddr = ipHeader.sourceAddress

            return "\(sourceAddr[0]).\(sourceAddr[1]).\(sourceAddr[2]).\(sourceAddr[3])"
        }
        guard let data = data else {
            return
        }
        let icmpResponse = try? ICMP.extractResponse(from: data as NSData)
        if icmpResponse?.ipHeader != nil, ip == extractIPAddressBlock() {
            return
        }
        guard let currentStartDate = currentStartDate else {
            return
        }
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotDecodeRawData, userInfo: nil)
        let response = PingResponse(identifier: identifier, ipAddress: nil, sequenceNumber: Int64(currentSequenceNumber), duration: Date().timeIntervalSince(currentStartDate), error: error)
        observer?(self, response)

//        return scheduleNextPing()
    }

    func sendPing() {
        self.currentSequenceNumber += 1;
        self.currentStartDate = Date()

        let icmpConfiguration = ICMP.Configuration(identifier: UInt16(identifier), sequenceNumber: UInt16(currentSequenceNumber), payloadSize: UInt32(configuration.payloadSize))
        let icmp = ICMP(configuration: icmpConfiguration)

        guard let icmpPackage = icmp.createPackage(), let socket = socket, let address = ipv4address else {
            return
        }
        let socketError = CFSocketSendData(socket, address as CFData, icmpPackage as CFData, configuration.timeoutInterval)

        switch socketError {
        case .error:
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost, userInfo: [:])
            let response = PingResponse(identifier: self.identifier, ipAddress: nil, sequenceNumber: Int64(currentSequenceNumber), duration: Date().timeIntervalSince(currentStartDate!), error: error)
            observer?(self, response)

//            return self.scheduleNextPing()
        case .timeout:
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [:])
            let response = PingResponse(identifier: self.identifier, ipAddress: nil, sequenceNumber: Int64(currentSequenceNumber), duration: Date().timeIntervalSince(currentStartDate!), error: error)
            observer?(self, response)

//            return self.scheduleNextPing()
        default: break
        }

        let sequenceNumber = currentSequenceNumber
        timeoutBlock = { () -> Void in
            if sequenceNumber != self.currentSequenceNumber {
                return
            }

            self.timeoutBlock = nil
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [:])
            let response = PingResponse(identifier: self.identifier, ipAddress: nil, sequenceNumber: Int64(self.currentSequenceNumber), duration: Date().timeIntervalSince(self.currentStartDate!), error: error)
            self.observer?(self, response)
//            self.scheduleNextPing()
        }
    }
}

// Helper classes

public struct PingResponse {
    public let identifier: UInt32
    public let ipAddress: String?
    public let sequenceNumber: Int64
    public let duration: TimeInterval
    public let error: NSError?
}

public struct PingConfiguration {
    let pingInterval: TimeInterval
    let timeoutInterval: TimeInterval
    let payloadSize: UInt64

    public init(interval: TimeInterval = 1, with timeout: TimeInterval = 5, and payload: UInt64 = 64) {
        pingInterval = interval
        timeoutInterval = timeout
        payloadSize = payload
    }

    public init(interval: TimeInterval) {
        self.init(interval: interval, with: 5)
    }

    public init(interval: TimeInterval, with timeout: TimeInterval) {
        self.init(interval: interval, with: timeout, and: 64)
    }
}

func check(sum: UnsafeMutableRawPointer, length: Int) -> UInt16 {
    var bufferLength = length
    var checksum: UInt32 = 0
    var buffer = sum.assumingMemoryBound(to: UInt16.self)

    let size = MemoryLayout<UInt16>.size
    while bufferLength > 1 {
        checksum += UInt32(buffer.pointee)
        buffer = buffer.successor()
        bufferLength -= size
    }
    if bufferLength == 1 {
        checksum += UInt32(UnsafeMutablePointer<UInt16>(buffer).pointee)
    }
    checksum = (checksum >> 16) + (checksum & 0xFFFF)
    checksum += checksum >> 16
    return ~UInt16(checksum)
}

public struct ICMP {
    public struct Configuration {
        public let identifier: UInt16
        public let sequenceNumber: UInt16
        public let payloadSize: UInt32
    }

    public let configuration: Configuration

    public func createPackage() -> NSData? {
        let packageDebug = false  // triggers print statements below

        var icmpType = ICMPType.EchoRequest.rawValue
        var icmpCode: UInt8 = 0
        var icmpChecksum: UInt16 = 0
        var icmpIdentifier = configuration.identifier
        var icmpSequence = configuration.sequenceNumber

        let payloadSize = configuration.payloadSize

        let packet = [String](repeatElement("0", count: Int(payloadSize))).joined()
        guard let packetData = packet.data(using: .utf8) else {
            return nil
        }
        var payload = NSData(data: packetData)
        payload = payload.subdata(with: NSRange(location: 0, length: Int(payloadSize))) as NSData
        guard let package = NSMutableData(capacity: MemoryLayout<ICMP.Header>.size + payload.length) else {
            return nil
        }
        package.replaceBytes(in: NSRange(location: 0, length: 1), withBytes: &icmpType)
        package.replaceBytes(in: NSRange(location: 1, length: 1), withBytes: &icmpCode)
        package.replaceBytes(in: NSRange(location: 2, length: 2), withBytes: &icmpChecksum)
        package.replaceBytes(in: NSRange(location: 4, length: 2), withBytes: &icmpIdentifier)
        package.replaceBytes(in: NSRange(location: 6, length: 2), withBytes: &icmpSequence)
        package.replaceBytes(in: NSRange(location: 8, length: payload.length), withBytes: payload.bytes)

        let bytes = package.mutableBytes
        icmpChecksum = check(sum: bytes, length: package.length)
        package.replaceBytes(in: NSRange(location: 2, length: 2), withBytes: &icmpChecksum)
        if packageDebug {
            print("ping package: \(package)")
        }
        return package
    }

    public struct Response {
        public let ipHeader: NSData?
        public let ipData: NSData?
        public let headerData: NSData?
        public let data: NSData?
    }

    public enum ResponseError: Error {
        case invalidBuffer
        case invalidBufferLength
        case checksumMismatch
    }

    public static func extractResponse(from data: NSData) throws -> Response {
        guard let buffer = data.mutableCopy() as? NSMutableData, buffer.length >= MemoryLayout<IPHeader>.size + MemoryLayout<ICMP.Header>.size else {
            throw ResponseError.invalidBuffer
        }

        var mutableBytes = buffer.mutableBytes

        let ipHeader = withUnsafePointer(to: &mutableBytes) { (temp) in
            return unsafeBitCast(temp, to: IPHeader.self)
        }

        // IPv4 and ICMP
        guard ipHeader.versionAndHeaderLength & 0xF0 == 0x40, ipHeader.protocol == 1 else {
            throw ResponseError.invalidBuffer
        }

        let ipHeaderLength = (ipHeader.versionAndHeaderLength & 0x0F) * UInt8(MemoryLayout<UInt32>.size)
        if buffer.length < Int(ipHeaderLength) + MemoryLayout<ICMP.Header>.size {
            throw ResponseError.invalidBufferLength
        }

        let range = NSMakeRange(0, MemoryLayout<IPHeader>.size)
        let ipHeaderData = buffer.subdata(with: range) as NSData?

        var ipData: NSData?
        if buffer.length >= MemoryLayout<IPHeader>.size + Int(ipHeaderLength) {
            ipData = buffer.subdata(with: NSMakeRange(MemoryLayout<IPHeader>.size, Int(ipHeaderLength))) as NSData?
        }

        let icmpHeaderOffset = size_t(ipHeaderLength)

        var headerBuffer = mutableBytes.assumingMemoryBound(to: UInt8.self) + icmpHeaderOffset

        var icmpHeader = withUnsafePointer(to: &headerBuffer) { (temp) in
            return unsafeBitCast(temp, to: ICMP.Header.self)
        }

        let receivedChecksum = icmpHeader.checkSum
        let calculatedChecksum = check(sum: &icmpHeader, length: buffer.length - icmpHeaderOffset)
        icmpHeader.checkSum = receivedChecksum

        guard receivedChecksum == calculatedChecksum else {
            print("invalid ICMP header. Checksums did not match")
            throw ResponseError.checksumMismatch
        }

        let icmpDataRange = NSMakeRange(icmpHeaderOffset + MemoryLayout<ICMP.Header>.size, buffer.length - (icmpHeaderOffset + MemoryLayout<ICMP.Header>.size))
        let icmpHeaderData = buffer.subdata(with: NSMakeRange(icmpHeaderOffset, MemoryLayout<ICMP.Header>.size)) as NSData?
        let icmpData = buffer.subdata(with: icmpDataRange) as NSData?

        return Response(ipHeader: ipHeaderData, ipData: ipData, headerData: icmpHeaderData, data: icmpData)
    }

    public struct Header {
        var type: UInt8      /* type of message*/
        var code: UInt8      /* type sub code */
        var checkSum: UInt16 /* ones complement cksum of struct */
        var identifier: UInt16
        var sequenceNumber: UInt16
        var data: timeval
    }

    // ICMP type and code combinations:

    public enum ICMPType: UInt8 {
        case EchoReply = 0           // code is always 0
        case EchoRequest = 8            // code is always 0
    }
}

public struct IPHeader {
    var versionAndHeaderLength: UInt8
    var differentiatedServices: UInt8
    var totalLength: UInt16
    var identification: UInt16
    var flagsAndFragmentOffset: UInt16
    var timeToLive: UInt8
    var `protocol`: UInt8
    var headerChecksum: UInt16
    var sourceAddress: [UInt8]
    var destinationAddress: [UInt8]
}


extension Data {
    public var socketAddress: sockaddr {
        return self.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) -> sockaddr in
            let raw = UnsafeRawPointer(pointer)
            let address = raw.assumingMemoryBound(to: sockaddr.self).pointee
            return address
        }
    }
    public var socketAddressInternet: sockaddr_in {
        return self.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) -> sockaddr_in in
            let raw = UnsafeRawPointer(pointer)
            let address = raw.assumingMemoryBound(to: sockaddr_in.self).pointee
            return address
        }
    }
}
