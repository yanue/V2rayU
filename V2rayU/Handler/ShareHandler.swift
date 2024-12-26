import Cocoa

class ShareUri {
    var error = ""
    var uri: String = ""

    func qrcode(item: ProfileModel) {

        switch item.protocol {
        case .trojan:
            self.uri = TrojanUri(from: item).encode()
            break
        case .vmess:
            self.uri = VmessUri(from: item).encode()
            break
        case .vless:
            self.uri = VlessUri(from: item).encode()
            break
        case .shadowsocks:
            self.uri = ShadowsocksUri(from: item).encode()
            break
        default:
            break
        }

        self.error = "not support"
    }
}
