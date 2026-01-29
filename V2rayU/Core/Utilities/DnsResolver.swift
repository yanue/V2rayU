//
//  DnsResolver.swift
//  V2rayU
//
//  Created by yanue on 2026/1/29.
//
import Foundation

enum DNSError: Error {
    case resolutionFailed(String)
    case noAddressFound
}

struct DNSResolver {
    
    static func resolve(hostname: String, family: Int32 = AF_UNSPEC) throws -> [String] {
        var hints = addrinfo(
            ai_flags: AI_DEFAULT,
            ai_family: family,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        
        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(hostname, nil, &hints, &result)
        
        guard status == 0 else {
            let errorMsg = String(cString: gai_strerror(status))
            throw DNSError.resolutionFailed(errorMsg)
        }
        
        defer { freeaddrinfo(result) }
        
        var addresses: [String] = []
        var current = result
        
        while let info = current?.pointee {
            if let addr = info.ai_addr {
                var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                
                let ret = getnameinfo(
                    addr,
                    socklen_t(info.ai_addrlen),
                    &buffer,
                    socklen_t(buffer.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                
                if ret == 0 {
                    if let end = buffer.firstIndex(of: 0) {
                        let slice = buffer[..<end].map { UInt8($0) }
                        if let address = String(bytes: slice, encoding: .utf8) {
                            addresses.append(address)
                        }
                    }
                }
            }
            current = info.ai_next
        }
        
        guard !addresses.isEmpty else {
            throw DNSError.noAddressFound
        }
        
        return addresses
    }
    
    static func resolveAsync(hostname: String, family: Int32 = AF_UNSPEC) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let addresses = try resolve(hostname: hostname, family: family)
                    continuation.resume(returning: addresses)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // 便捷方法
    static func resolveIPv4(hostname: String) throws -> [String] {
        return try resolve(hostname: hostname, family: AF_INET)
    }
    
    static func resolveIPv6(hostname: String) throws -> [String] {
        return try resolve(hostname: hostname, family: AF_INET6)
    }
}
