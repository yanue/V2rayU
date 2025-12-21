//
//  String+Extension.swift
//  V2rayU
//
//  Created by yanue on 2018/10/12.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation

extension String {
    // version compare
    func versionToInt() -> [Int] {
        return components(separatedBy: ".")
            .map {
                Int($0) ?? 0
            }
    }

    //: ### Base64 encoding a string
    func base64Encoded() -> String? {
        if let data = data(using: .utf8) {
            return data.base64EncodedString()
        }
        return nil
    }

    //: ### Base64 decoding a string
    func base64Decoded() -> String? {
        if let _ = range(of: ":")?.lowerBound {
            return self
        }
        let base64String = replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = base64String.count + (base64String.count % 4 != 0 ? (4 - base64String.count % 4) : 0)
        if let decodedData = Data(base64Encoded: base64String.padding(toLength: padding, withPad: "=", startingAt: 0), options: NSData.Base64DecodingOptions(rawValue: 0)), let decodedString = NSString(data: decodedData, encoding: String.Encoding.utf8.rawValue) {
            return decodedString as String
        }
        return nil
    }

    //: isValidUrl
    func isValidUrl() -> Bool {
        let urlRegEx = "(https?|ftp|file)://[-A-Za-z0-9+&@#/%?=~_|!:,.;]+[-A-Za-z0-9+&@#/%=~_|]"
        let urlTest = NSPredicate(format: "SELF MATCHES %@", urlRegEx)
        let result = urlTest.evaluate(with: self)
        return result
    }

    // 将原始的url编码为合法的url
    func urlEncoded() -> String {
        let encodeUrlString = addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        return encodeUrlString ?? self
    }

    // 将编码后的url转换回原始的url
    func urlDecoded() -> String {
        return removingPercentEncoding ?? self
    }
}

extension utsname {
    static var sMachine: String {
        var utsname = utsname()
        uname(&utsname)
        return withUnsafePointer(to: &utsname.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }
    }

    static var isAppleSilicon: Bool {
        sMachine == "arm64"
    }
}

extension Int {
    var formattedDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(self))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

extension Int {
    func localizedInterval(locale: Locale = .current) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.zeroFormattingBehavior = .dropAll
        formatter.calendar = Calendar.current
        formatter.calendar?.locale = locale
        return formatter.string(from: TimeInterval(self)) ?? "\(self)"
    }
}

extension String {
    func safeBase64Encoded() -> String? {
        let data = self.data(using: .utf8)
        return data?.base64EncodedString()
    }

    func safeBase64Decoded() -> String? {
        var s = self
        // Normalize URL-safe base64
        s = s.replacingOccurrences(of: "-", with: "+")
             .replacingOccurrences(of: "_", with: "/")
        // Pad to multiple of 4
        let rem = s.count % 4
        if rem != 0 {
            s.append(String(repeating: "=", count: 4 - rem))
        }
        guard let data = Data(base64Encoded: s) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
