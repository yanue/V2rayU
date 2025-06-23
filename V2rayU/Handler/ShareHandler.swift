import Cocoa

class ShareUri {
    var error = ""
    var uri: String = ""

    static func generateShareUri(item: ProfileModel) -> String {
        let handler = ShareUri()
        
        switch item.protocol {
        case .trojan:
            handler.uri = TrojanUri(from: item).encode()
        case .vmess:
            handler.uri = VmessUri(from: item).encode()
        case .vless:
            handler.uri = VlessUri(from: item).encode()
        case .shadowsocks:
            handler.uri = ShadowsocksUri(from: item).encode()
        default:
            handler.error = "Protocol not supported"
            return ""
        }
        
        return handler.uri
    }
}
