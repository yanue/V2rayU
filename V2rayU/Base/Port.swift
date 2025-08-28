//
//  UserDefaults.swift
//  V2rayU
//
//  Created by yanue on 2024/12/25.
//  Copyright © 2024 yanue. All rights reserved.

import Foundation

// https://stackoverflow.com/questions/65670932/how-to-find-a-free-local-port-using-swift
func findFreePort() -> UInt16 {
    var port: UInt16 = 8000

    let socketFD = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    if socketFD == -1 {
        // logger.info("Error creating socket: \(errno)")
        return port
    }

    var hints = addrinfo(
        ai_flags: AI_PASSIVE,
        ai_family: AF_INET,
        ai_socktype: SOCK_STREAM,
        ai_protocol: 0,
        ai_addrlen: 0,
        ai_canonname: nil,
        ai_addr: nil,
        ai_next: nil
    )

    var addressInfo: UnsafeMutablePointer<addrinfo>?
    var result = getaddrinfo(nil, "0", &hints, &addressInfo)
    if result != 0 {
        // logger.info("Error getting address info: \(errno)")
        close(socketFD)
        return port
    }

    result = Darwin.bind(socketFD, addressInfo!.pointee.ai_addr, socklen_t(addressInfo!.pointee.ai_addrlen))
    if result == -1 {
        // logger.info("Error binding socket to an address: \(errno)")
        close(socketFD)
        return port
    }

    result = Darwin.listen(socketFD, 1)
    if result == -1 {
        // logger.info("Error setting socket to listen: \(errno)")
        close(socketFD)
        return port
    }

    var addr_in = sockaddr_in()
    addr_in.sin_len = UInt8(MemoryLayout.size(ofValue: addr_in))
    addr_in.sin_family = sa_family_t(AF_INET)

    var len = socklen_t(addr_in.sin_len)
    result = withUnsafeMutablePointer(to: &addr_in, {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            Darwin.getsockname(socketFD, $0, &len)
        }
    })

    if result == 0 {
        port = addr_in.sin_port
    }

    Darwin.shutdown(socketFD, SHUT_RDWR)
    close(socketFD)

    return port
}

func isPortOpen(port: UInt16) -> Bool {
    do {
        let output = try runCommand(at: "/usr/sbin/lsof", with: ["-i", ":\(port)"])
        return output.contains("LISTEN")
    } catch let error {
        logger.info("isPortOpen: \(error)")
    }
    return false
}

func getUsablePort(port: UInt16) -> (Bool, UInt16) {
    var i = 0
    var isNew = false
    var _port = port
    while i < 100 {
        let opened = isPortOpen(port: _port)
        logger.info("getUsablePort: try=\(i) port=\(_port) opened=\(opened)")
        if !opened {
            return (isNew, _port)
        }
        isNew = true
        i += 1
        _port += 1
    }
    return (isNew, _port)
}

// can't use this (crash when launchctl)
func closePort(port: UInt16) {
    let process = Process()
    process.launchPath = "/usr/sbin/lsof"
    process.arguments = ["-ti", ":\(port)"]

    let pipe = Pipe()
    process.standardOutput = pipe

    process.terminationHandler = { _ in
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            let pids = output.split(separator: "\n")
            for pid in pids {
                if let pid = Int(String(pid)) {
                    killProcess(processIdentifier: pid_t(pid))
                }
            }
        }
    }
    process.launch()
    process.waitUntilExit()
}
