import Foundation

// link: https://github.com/shadowsocks/ShadowsocksX-NG
class ShadowsocksUri: BaseShareUri {
    var profile: ProfileEntity
    var error: String?

    // 初始化
    init() {
        self.profile = ProfileEntity(remark: "ss", protocol: .shadowsocks)
    }

    // 从 ProfileModel 初始化
    required init(from model: ProfileEntity) {
        // 通过传入的 model 初始化 Profile 类的所有属性
        self.profile = model
    }

    func getProfile() -> ProfileEntity {
        return self.profile
    }

    // ss://bf-cfb:test@192.168.100.1:8888#remark
    func encode() -> String {
        let base64 = self.profile.encryption + ":" + self.profile.password + "@" + self.profile.host + ":" + String(self.profile.port)
        let ss = base64.base64Encoded()
        if ss != nil {
            return "ss://" + ss! + "#" + self.profile.remark.urlEncoded()
        }
        self.error = "encode base64 fail"
        return ""
    }

    func parse(url: URL) -> Error? {
        let (_decodedUrl, _tag) = self.decodeUrl(url: url)
        guard let decodedUrl = _decodedUrl else {
            return NSError(domain: "ShadowsocksUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "error: decodeUrl"])
        }
        guard let parsedUrl = URLComponents(string: decodedUrl) else {
            return NSError(domain: "ShadowsocksUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "error: parsedUrl"])
        }
        guard let host = parsedUrl.host else {
            return NSError(domain: "ShadowsocksUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "error: missing host"])
        }
        guard let port = parsedUrl.port else {
            return NSError(domain: "ShadowsocksUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "error: missing port"])
        }
        guard let user = parsedUrl.user else {
            return NSError(domain: "ShadowsocksUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "error: missing user"])
        }

        self.profile.address = host
        self.profile.port = Int(port)

        // This can be overriden by the fragment part of SIP002 URL
        self.profile.remark = (parsedUrl.queryItems?.filter({ $0.name == "Remark" }).first?.value ?? _tag ?? "").urlDecoded()

        if let password = parsedUrl.password {
            self.profile.encryption = user.lowercased()
            self.profile.password = password
            if let tag = _tag {
               self.profile.remark = tag
            }
        } else {
            // SIP002 URL have no password section
            guard let data = Data(base64Encoded: self.padBase64(string: user)), let userInfo = String(data: data, encoding: .utf8) else {
                return NSError(domain: "ShadowsocksUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "error: URL: have no password section"])
            }

            let parts = userInfo.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count != 2 {
                return NSError(domain: "ShadowsocksUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "error: url userInfo"])
            }

            self.profile.encryption = String(parts[0]).lowercased()
            self.profile.password = String(parts[1])

            // SIP002 defines where to put the profile name
            if let profileName = parsedUrl.fragment {
                self.profile.remark = profileName.urlDecoded()
            }
        }
        return nil
    }

    func decodeUrl(url: URL) -> (String?, String?) {
        let urlStr = url.absoluteString
        let base64Begin = urlStr.index(urlStr.startIndex, offsetBy: 5)
        let base64End = urlStr.firstIndex(of: "#")
        let encodedStr = String(urlStr[base64Begin..<(base64End ?? urlStr.endIndex)])

        guard let decoded = encodedStr.base64Decoded() else {
            self.error = "decode ss error"
            return (url.absoluteString, nil)
        }

        let s = decoded.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = base64End {
            let i = urlStr.index(index, offsetBy: 1)
            let fragment = String(urlStr[i...]).removingPercentEncoding
            return ("ss://\(s)", fragment)
        }
        return ("ss://\(s)", nil)
    }

    func padBase64(string: String) -> String {
        var length = string.utf8.count
        if length % 4 == 0 {
            return string
        } else {
            length = 4 - length % 4 + length
            return string.padding(toLength: length, withPad: "=", startingAt: 0)
        }
    }
}
