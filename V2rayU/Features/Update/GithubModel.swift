import SwiftUI

struct GithubRelease: Codable, Equatable, Hashable {
    let id: Int
    let tagName: String
    let name: String
    let draft: Bool
    let prerelease: Bool
    let publishedAt: Date // 2024-06-30T09:00:00Z, 用于排序
    let assets: [GithubAsset]
    let body: String

    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case name
        case draft
        case prerelease
        case publishedAt = "published_at"
        case assets
        case body
    }

    static func == (lhs: GithubRelease, rhs: GithubRelease) -> Bool {
        return lhs.tagName == rhs.tagName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(tagName)
    }

    var formattedPublishedAt: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.string(from: publishedAt)
    }

    func getDownloadAsset() -> GithubAsset {
        let arch = getArch()
        let V2rayU = "V2rayU"

        // 根据 assets 和当前架构选择正确的
        for asset in self.assets {
            logger.debug("asset: \(asset.browserDownloadUrl),")
            let lowerName = asset.browserDownloadUrl.lowercased()
            
            // https://github.com/XTLS/Xray-core/releases/download/v25.10.15/Xray-macos-64.zip 需要包含·macos·
            // https://github.com/yanue/V2rayU/releases/download/v4.2.8/V2rayU-arm64.dmg
            var suffix: String = ".zip"
            var contains: String = "macos"
            
            // 判断是V2rayU
            
            if lowerName.contains(V2rayU.lowercased()) {
                suffix = ".dmg"
                contains = V2rayU.lowercased()
            }
            
            // 判断
            if lowerName.hasSuffix(suffix) && lowerName.contains(contains) {
                // GithubAsset: Xray-macos-arm64-v8a.zip -> xray-macos-arm64-v8a.zip
                if arch == "arm64" && lowerName.contains("arm64") {
                    return asset
                }
                // GithubAsset: Xray-macos-64.zip -> xray-macos-64.zip
                if arch != "arm64" && !lowerName.contains("arm64") {
                    return asset
                }
            }
        }
        return GithubAsset(name: "", browserDownloadUrl: "", size: 0)
    }
}

struct GithubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int64

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

struct GithubError: Codable {
    let message: String
    let documentationUrl: String

    enum CodingKeys: String, CodingKey {
        case message
        case documentationUrl = "documentation_url"
    }
}
