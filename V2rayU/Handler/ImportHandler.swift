//
// Created by yanue on 2018/11/22.
// Copyright (c) 2018 yanue. All rights reserved.
//

import Cocoa
import CoreGraphics
import CoreImage

func importUri(url: String) {
    let urls = url.split(separator: "\n")

    for url in urls {
        let uri = url.trimmingCharacters(in: .whitespaces)

        if uri.count == 0 {
            noticeTip(title: "import server fail", informativeText: "import error: uri not found")
            continue
        }

        let importUri = ImportUri(share_uri: uri)

        if let profile = importUri.doImport() {
            // 保存到数据库
            ProfileStore.shared.insert(profile)
            continue
        } else {
            noticeTip(title: "import server fail", informativeText: importUri.error)
        }
    }
}

func supportProtocol(uri: String) -> Bool {
    if uri.hasPrefix("ss://") || uri.hasPrefix("ssr://") || uri.hasPrefix("vmess://") || uri.hasPrefix("vless://") || uri.hasPrefix("trojan://") {
        return true
    }
    return false
}

class ImportUri {
    var isValid: Bool = false
    var error: String = ""
    var remark: String = ""
    private var share_uri: String = ""

    init(share_uri: String) {
        self.share_uri = share_uri
    }

    func doImport() -> ProfileEntity? {
        var url = URL(string: share_uri)
        if url == nil {
            // 标准url不支持非url-encoded
            let aUri = self.share_uri.split(separator: "#")
            url = URL(string: String(aUri[0]))
            if url == nil {
                self.error = "invalid url"
                return nil
            }
            if aUri.count > 1 {
                self.remark = String(aUri[1]).urlDecoded()
            }
        }

        // 定义变量
        var uriHandler: BaseShareUri?

        // 根据 URI 前缀选择对应处理类
        if share_uri.hasPrefix("trojan://") {
            uriHandler = TrojanUri()
        } else if share_uri.hasPrefix("vmess://") {
            uriHandler = VmessUri()
        } else if share_uri.hasPrefix("vless://") {
            uriHandler = VlessUri()
        } else if share_uri.hasPrefix("ss://") {
            uriHandler = ShadowsocksUri()
        } else if share_uri.hasPrefix("ssr://") {
            uriHandler = ShadowsocksRUri()
        }

        // 解析 URI
        if let handler = uriHandler {
            let parseError = handler.parse(url: url!)
            if let error = parseError {
                // 如果解析失败，返回 nil
                return nil
            }
            // 解析成功返回 ProfileModel
            var profile = handler.getProfile()
            if self.remark.count > 0 {
                profile.remark = self.remark
            }
            return profile
        }

        return nil
    }

}
