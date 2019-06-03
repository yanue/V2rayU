//
//  httpServer.swift
//  HttpServer
//
//  Created by Koksharov Alexandr on 01/12/2018.
//  Copyright © 2018 Koksharov Alexandr. All rights reserved.
//

import Foundation

private let maxHeaderSize = 1024

enum HttpServerError: Error {
    case description(String)
}

public protocol HttpRequest {
    func getMethod() -> String
    func getPath() -> String
    func getVersion() -> String
    func getHeader(name: String) -> String?
    func getContent() throws -> String
}

public protocol HttpResponse {
    func setHeader(name: String, value: String) -> Void
    func setContent(body: String) -> Void
    func setStatusCode(code: Int) -> Void
}

class HttpServer {
    private let ip: String
    private let port: UInt16
    private let handler: (HttpRequest, HttpResponse) -> Void

    // client sock
    private var sock: Int32

    private let queue = DispatchQueue(label: "HttpServer", qos: .userInitiated, attributes: .concurrent)
    private var source: DispatchSourceRead? = nil

    init(ip: String, port: UInt16, handler: @escaping (HttpRequest, HttpResponse) -> Void) {
        self.ip = ip
        self.port = port
        self.handler = handler
        self.sock = 0
    }

    func run() {
        var addr = sockaddr_in(
                sin_len: UInt8(MemoryLayout<sockaddr_in>.size),
                sin_family: UInt8(AF_INET),
                sin_port: port.bigEndian,
                sin_addr: in_addr(s_addr: INADDR_ANY),
                sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )

        let listenSock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard listenSock > -1 else {
            print("listenSock \(errno.description)")
            return
        }
        var reuseVal: Int32 = 1
        setsockopt(listenSock, SOL_SOCKET, SO_REUSEPORT, &reuseVal, socklen_t(MemoryLayout<Int32>.size))

        withUnsafePointer(to: &addr) {
            let addrPtr = UnsafeRawPointer($0).assumingMemoryBound(to: sockaddr.self)
            guard bind(listenSock, addrPtr, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0 else {
                print("withUnsafePointer \(errno.description)")
                return
            }
        }

        guard listen(listenSock, 3) == 0 else {
            print("listen \(errno.description)")
            return
        }

        self.source = DispatchSource.makeReadSource(fileDescriptor: listenSock, queue: self.queue)
        if self.source == nil {
            print("cant create dispatch source")
            return
        }

        self.source!.setEventHandler {
            var clientAddr = sockaddr_storage()
            var clientAddrLen: socklen_t = socklen_t(MemoryLayout.size(ofValue: clientAddr))

            let clientSock = withUnsafeMutablePointer(to: &clientAddr) {
                accept(listenSock, UnsafeMutableRawPointer($0).assumingMemoryBound(to: sockaddr.self), &clientAddrLen)
            }
            guard clientSock > 0 else {
                print("clientSock \(errno.description)")
                return
            }
            var noSigPipe: Int32 = 1
            setsockopt(clientSock, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

            self.queue.async {
                self.handleClient(socket: clientSock)
                self.sock = clientSock
                close(clientSock)
            }

        }
        self.source!.resume()
    }

    func stop() {
        if self.sock > 0 {
            Darwin.shutdown(sock, SHUT_RDWR)
        }
        self.queue.async {
            close(self.sock)
        }
    }

    private func handleClient(socket sock: Int32) {
        do {
            let reader: HttpReader = try HttpReader(sock)
            let writer: HttpWriter = HttpWriter(sock)
            self.handler(reader, writer)
            try writer.writeResponse()
        } catch let e {
            print("\(e)")
        }
    }

}

private class HttpWriter: HttpResponse {
    private let socket: Int32

    private let version: String = "HTTP/1.0"
    private var statusCode: Int = 200
    private var header = [String: String]()
    private var body: String = ""

    init(_ socket: Int32) {
        self.socket = socket
    }

    func setHeader(name: String, value: String) {
        self.header[name] = value
    }

    func setContent(body: String) {
        self.body = body
    }

    func setStatusCode(code: Int) {
        self.statusCode = code
    }

    private func getStatusLine() -> String {
        return "\(version) \(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode))\r\n"
    }

    private func writeText(text: String) throws {
        try text.withCString { buf in
            var written = 0
            while written < text.lengthOfBytes(using: String.Encoding.utf8) {
                let len = write(self.socket, buf + written, text.lengthOfBytes(using: String.Encoding.utf8) - written)
                if len == -1 {
                    throw HttpServerError.description("\(errno.description)")
                }
                written = written + len
            }
        }
    }

    func writeResponse() throws {
        try writeText(text: getStatusLine())
        try header.forEach { (key, value) in
            try writeText(text: "\(key): \(value)\r\n")
        }
        try writeText(text: "\r\n\(self.body)")
    }
}

private class HttpReader: HttpRequest {
    private let socket: Int32
    private var isReadDone: Bool

    private var method: String = "UNDEF"
    private var path: String = "UNDEF"
    private var version: String = "UNDEF"

    private var header = [String: String]()
    private var body: String = ""
    private var bodyLength: Int = 0

    init(_ sock: Int32) throws {
        self.socket = sock
        self.isReadDone = false

        do {
            var httpHeader: String = ""
            var reqLine = ""
            var reqFields: String = ""

            repeat {
                let new = try readText(maxLen: maxHeaderSize - httpHeader.lengthOfBytes(using: String.Encoding.utf8))
                guard new.lengthOfBytes(using: String.Encoding.utf8) > 0 else {
                    throw HttpServerError.description("http header too short")
                }
                httpHeader.append(new)
                if let headerRange = httpHeader.range(of: "\r\n\r\n") {
                    guard let reqLineRange = httpHeader.range(of: "\r\n") else {
                        throw HttpServerError.description("http requestline read error")
                    }
                    reqLine = String(httpHeader[..<reqLineRange.lowerBound])
                    reqFields = String(httpHeader[reqLineRange.upperBound..<headerRange.lowerBound])
                    self.body = String(httpHeader[headerRange.upperBound...])
                } else {
                    if httpHeader.lengthOfBytes(using: String.Encoding.utf8) >= maxHeaderSize {
                        throw HttpServerError.description("http header too long")
                    }
                }
            } while reqLine == ""

            let requestComponents = reqLine.components(separatedBy: " ")
            guard requestComponents.count == 3 else {
                throw HttpServerError.description("cant parse request line: '\(reqLine)'")
            }
            self.method = requestComponents[0]
            self.path = requestComponents[1]
            self.version = requestComponents[2]

            reqFields.enumerateLines { (line, done) in
                let field = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
                if field.count == 2 {
                    self.header[field[0].lowercased()] = field[1].trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    print("cant parse header line. '\(field)'")
                }
            }

            if let lenStr = getHeader(name: "content-length"), let len = Int(lenStr) {
                self.bodyLength = len
            }

        } catch let e {
            throw e
        }
    }

    func getMethod() -> String {
        return self.method
    }

    func getPath() -> String {
        return self.path
    }

    func getVersion() -> String {
        return self.version
    }

    func getHeader(name: String) -> String? {
        return self.header[name.lowercased()]
    }

    func getContentLength() -> Int {
        return self.bodyLength
    }

    func getContent() throws -> String {
        while self.body.lengthOfBytes(using: String.Encoding.utf8) < self.bodyLength {
            do {
                let new = try readText(maxLen: Int(self.bodyLength) - self.body.lengthOfBytes(using: String.Encoding.utf8))
                self.body.append(new)
            } catch let e {
                throw e
            }
        }
        if self.body.lengthOfBytes(using: String.Encoding.utf8) > self.bodyLength {
            let i = self.body.index(self.body.startIndex, offsetBy: self.bodyLength)
            self.body = String(self.body[..<i])
        }
        return self.body
    }

    private func readText(maxLen: Int) throws -> String {
        let bytesPointer = UnsafeMutableRawPointer.allocate(byteCount: maxLen, alignment: 1)
        let len = read(self.socket, bytesPointer, maxLen)

        if (len == 0) {// client closed stream - EOF
            throw HttpServerError.description("Connection closed")
        }

        if len < 0 {
            throw HttpServerError.description(errno.description)
        }

        if let result = String.init(bytesNoCopy: bytesPointer, length: len, encoding: String.Encoding.utf8, freeWhenDone: true) {
            return result
        }

        throw HttpServerError.description("Request interpretation error. Binary data?")
    }
}
