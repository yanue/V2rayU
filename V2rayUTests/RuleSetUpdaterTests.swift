import Foundation
import Testing
@testable import V2rayU

/// 规则集自动更新: 路径解析、文件校验、设置读写
struct RuleSetUpdaterTests {
    @Test func singboxPathPrefersUserFile() {
        let user = RuleSetLocator.singboxRuleSetFile(tag: "geosite-cn", userDir: "/u", bundledDir: "/b") { $0 == "/u/geosite-cn.srs" }
        #expect(user == "/u/geosite-cn.srs")
        let bundled = RuleSetLocator.singboxRuleSetFile(tag: "geosite-cn", userDir: "/u", bundledDir: "/b") { _ in false }
        #expect(bundled == "/b/geosite-cn.srs")
    }

    @Test func xrayAssetDirNeedsBothFiles() {
        #expect(RuleSetLocator.xrayAssetDirectory(userDir: "/u") { _ in true } == "/u")
        #expect(RuleSetLocator.xrayAssetDirectory(userDir: "/u") { $0.hasSuffix("geoip.dat") } == nil)
        #expect(RuleSetLocator.xrayAssetDirectory(userDir: "/u") { _ in false } == nil)
    }

    @Test func completeXrayAssetsCopiesMissingBundledFile() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ruleset-\(UUID().uuidString)")
        let user = root.appendingPathComponent("user").path
        let bundled = root.appendingPathComponent("bundled").path
        try fm.createDirectory(atPath: user, withIntermediateDirectories: true)
        try fm.createDirectory(atPath: bundled, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        try Data("new-site".utf8).write(to: URL(fileURLWithPath: user + "/geosite.dat"))
        try Data("old-ip".utf8).write(to: URL(fileURLWithPath: bundled + "/geoip.dat"))
        try Data("old-site".utf8).write(to: URL(fileURLWithPath: bundled + "/geosite.dat"))

        RuleSetUpdater.completeXrayAssets(userDir: user, bundledDir: bundled)

        #expect(fm.contents(atPath: user + "/geoip.dat") == Data("old-ip".utf8))
        // 已经更新的那个不能被安装目录的旧文件覆盖
        #expect(fm.contents(atPath: user + "/geosite.dat") == Data("new-site".utf8))
        #expect(RuleSetLocator.xrayAssetDirectory(userDir: user) == user)
    }

    @Test func validateRejectsErrorPages() {
        let html = Data(String(repeating: "<html>error</html>", count: 10).utf8)
        #expect(throws: (any Error).self) { try RuleSetUpdater.validate(html, fileName: "geoip.dat") }
        #expect(throws: (any Error).self) { try RuleSetUpdater.validate(html, fileName: "geosite-cn.srs") }
        #expect(throws: (any Error).self) { try RuleSetUpdater.validate(Data("SRS".utf8), fileName: "geosite-cn.srs") }

        var srs = Data("SRS".utf8); srs.append(Data(repeating: 1, count: 100))
        #expect(throws: Never.self) { try RuleSetUpdater.validate(srs, fileName: "geosite-cn.srs") }
        var dat = Data([0x0a, 0x20]); dat.append(Data(repeating: 7, count: 200))
        #expect(throws: Never.self) { try RuleSetUpdater.validate(dat, fileName: "geoip.dat") }
    }

    @Test func defaultsCoverBundledRuleSetsAndXrayGeoFiles() {
        let singbox = Set(RuleSetSource.defaults.filter { $0.core == .singbox }.map(\.fileName))
        #expect(singbox == Set(singboxBundledRuleSetFiles))
        let xray = Set(RuleSetSource.defaults.filter { $0.core == .xray }.map(\.fileName))
        #expect(xray == ["geoip.dat", "geosite.dat"])
        #expect(Set(RuleSetSource.defaults.map(\.id)).count == RuleSetSource.defaults.count)
    }

    @Test func intervalNormalization() {
        #expect(RuleSetUpdater.normalizedInterval(0) == RuleSetUpdater.defaultInterval)
        #expect(RuleSetUpdater.normalizedInterval(-1) == RuleSetUpdater.defaultInterval)
        #expect(RuleSetUpdater.normalizedInterval(3600) == 3600)
        #expect(RuleSetUpdater.normalizedInterval(Int.max) == 365 * 86400)
    }

    @Test func sourcesRoundTripThroughUserDefaults() {
        let saved = RuleSetUpdater.sources
        defer { RuleSetUpdater.sources = saved }

        var custom = RuleSetSource.defaults
        custom[0].url = "https://example.com/geoip.dat"
        custom[1].enabled = false
        RuleSetUpdater.sources = custom
        #expect(RuleSetUpdater.sources == custom)

        RuleSetUpdater.resetSources()
        #expect(RuleSetUpdater.sources == RuleSetSource.defaults)
    }
}
