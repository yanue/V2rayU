import Foundation

// link: https://coderschool.cn/2498.html
// ssr://server:port:protocol:method:obfs:password_base64/?params_base64
// 上面的链接的不同之处在于 password_base64 和 params_base64 ，顾名思义，password_base64 就是密码被 base64编码 后的字符串，而 params_base64 则是协议参数、混淆参数、备注及Group对应的参数值被 base64编码 后拼接而成的字符串。

class ShadowsocksRUri: ShadowsocksUri {
    // 初始化
    override init() {
        super.init()
    }
    
    // 从 ProfileModel 初始化
    required init(from model: ProfileModel) {
        super.init(from: model)
    }

    override func getProfile() -> ProfileModel {
        return self.profile
    }

    override func parse(url: URL) -> Error? {
        let (_decodedUrl, _tag) = self.decodeUrl(url: url)
        guard let decodedUrl = _decodedUrl else {
            return NSError(domain: "ShadowsocksUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "error: decodeUrl"])
        }

        let parts: Array<Substring> = decodedUrl.split(separator: ":")
        if parts.count != 6 {
            return NSError(domain: "ShadowsocksUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "error: url"])
        }

        let host: String = String(parts[0])
        let port = String(parts[1])
        let method = String(parts[3])
        let passwordBase64 = String(parts[5])

        self.profile.address = host
        if let aPort = Int(port) {
            self.profile.port = aPort
        }

        self.profile.encryption = method.lowercased()
        if let tag = _tag {
            self.profile.remark = tag.urlDecoded()
        }

        guard let data = Data(base64Encoded: self.padBase64(string: passwordBase64)), let password = String(data: data, encoding: .utf8) else {
            return NSError(domain: "ShadowsocksUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "URL: password decode error"])
        }
        self.profile.password = password
        return nil
    }

    override func decodeUrl(url: URL) -> (String?, String?) {
        let urlStr = url.absoluteString
        // remove left ssr://
        let base64Begin = urlStr.index(urlStr.startIndex, offsetBy: 6)
        let encodedStr = String(urlStr[base64Begin...])

        guard let decoded = encodedStr.base64Decoded() else {
            self.error = "decode ssr error"
            return (url.absoluteString, nil)
        }

        let raw = decoded.trimmingCharacters(in: .whitespacesAndNewlines)

        let sep = raw.range(of: "/?")
        let s = String(raw[..<(sep?.lowerBound ?? raw.endIndex)])
        if let iBeg = raw.range(of: "remarks=")?.upperBound {
            let fragment = String(raw[iBeg...])
            let iEnd = fragment.firstIndex(of: "&")
            let aRemarks = String(fragment[..<(iEnd ?? fragment.endIndex)])
            guard let tag = aRemarks.base64Decoded() else {
                return (s, aRemarks)
            }
            return (s, tag)
        }

        return (s, nil)
    }
}
