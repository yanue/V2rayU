import Foundation
import GRDB
import Testing
@testable import V2rayU

/// 日志查看: 级别识别、尾部读取、过滤
struct LogViewTests {
    @Test func detectsLevels() {
        #expect(LogLevel.detect("+0800 2026-10-28 23:38:40 INFO [3169129007 0ms] inbound/mixed[mixed-in]: x") == .info)
        #expect(LogLevel.detect("+0800 2026-10-28 23:38:40 WARN [1] dns: timeout") == .warn)
        #expect(LogLevel.detect("+0800 2026-10-28 23:38:40 ERROR [1] outbound: dial failed") == .error)
        #expect(LogLevel.detect("2026/10/28 23:38:40 [Warning] [1] proxy/vmess: failed") == .warn)
        #expect(LogLevel.detect("2026/10/28 23:38:40 [Error] app/proxyman: x") == .error)
        #expect(LogLevel.detect("2026/10/28 23:38:40 [Debug] x") == .debug)
        #expect(LogLevel.detect("FATAL[0000] start service: x") == .error)
        #expect(LogLevel.detect("plain line") == .info)
    }

    @Test func splitAndFilter() {
        let lines = LogTail.split("a INFO x\nb ERROR y\n\nc WARN z\n")
        #expect(lines.count == 3)
        #expect(LogTail.filter(lines, level: .error, keyword: "").map(\.text) == ["b ERROR y"])
        #expect(LogTail.filter(lines, level: .all, keyword: "Z").map(\.text) == ["c WARN z"])
        #expect(LogTail.filter(lines, level: .warn, keyword: "nothing").isEmpty)
    }

    @Test func readsTailThenAppendsIncrementally() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("v2rayu-log-\(UUID().uuidString).log").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        var text = ""
        for i in 0..<20000 { text += "line \(i) INFO padding padding padding padding\n" }
        try text.write(toFile: path, atomically: true, encoding: .utf8)

        // 第一次只读尾部, 丢掉被截断的半行
        let first = try #require(LogTail.read(path: path, from: 0))
        #expect(first.lines.last == "line 19999 INFO padding padding padding padding")
        #expect(first.lines.first?.hasPrefix("line ") == true)
        #expect(first.partial == "")
        #expect(first.offset == UInt64(text.utf8.count))

        // 追加一行半: 完整行返回, 半行留到下次
        let h = FileHandle(forWritingAtPath: path)!
        try h.seekToEnd(); try h.write(contentsOf: Data("new A\nnew B".utf8)); try h.close()
        let second = try #require(LogTail.read(path: path, from: first.offset, partial: first.partial))
        #expect(second.lines == ["new A"])
        #expect(second.partial == "new B")
        let h2 = FileHandle(forWritingAtPath: path)!
        try h2.seekToEnd(); try h2.write(contentsOf: Data(" done\n".utf8)); try h2.close()
        let third = try #require(LogTail.read(path: path, from: second.offset, partial: second.partial))
        #expect(third.lines == ["new B done"])

        // 文件被清空: 从头来
        try "fresh\n".write(toFile: path, atomically: false, encoding: .utf8)
        let fourth = try #require(LogTail.read(path: path, from: third.offset, partial: third.partial))
        #expect(fourth.lines == ["fresh"])
        #expect(LogTail.read(path: "/nonexistent/x.log", from: 0) == nil)
    }
}

/// 按进程分流解析
struct ProcessRuleTests {
    @Test func parsesProcessLines() {
        let (names, paths) = parseProcessRules("domain:a.com\nprocess:Telegram\nPROCESS: Safari \nprocess:/Applications/Xcode.app\nprocess:Telegram\nprocess:")
        #expect(names == ["Telegram", "Safari"])
        #expect(paths == ["/Applications/Xcode.app"])
    }

    @Test func processLinesAreNotDomains() {
        let (domains, ips) = parseDomainOrIp(domainIpStr: "process:Telegram\nexample.com\n1.2.3.4")
        #expect(domains == ["example.com"])
        #expect(ips == ["1.2.3.4"])
    }

    @Test func pathRegex() {
        #expect(processPathRegex("/usr/local/bin/curl") == "^/usr/local/bin/curl$")
        #expect(processPathRegex("/Applications/Xcode.app") == "^/Applications/Xcode\\.app/")
    }

    @Test func routeRulesFromEntity() {
        let entity = RoutingEntity(name: "custom", remark: "x", block: "process:Ads", proxy: "process:Telegram\nprocess:/Applications/Discord.app", direct: "geoip:cn")
        let rules = RoutingManager.processRouteRules(for: entity)
        #expect(rules.count == 3)
        #expect(rules[0].outbound == "block" && rules[0].process_name == ["Ads"])
        #expect(rules[1].outbound == "proxy" && rules[1].process_name == ["Telegram"])
        #expect(rules[2].outbound == "proxy" && rules[2].process_path_regex == ["^/Applications/Discord\\.app/"])
    }
}

/// 下载测速显示
struct SpeedTestFormatTests {
    @Test func formats() {
        #expect(formatDownloadSpeed(0) == "-")
        #expect(formatDownloadSpeed(-1) == "-")
        #expect(formatDownloadSpeed(10 * 1024 * 1024).hasSuffix("/s"))
    }
}

/// 备份 / 恢复: 导出再解包, 内容一致
struct BackupHandlerTests {
    @Test func exportUnpackRoundTrip() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("v2rayu-backup-test-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        // 独立的临时库, 不碰真实数据
        let source = try DatabaseQueue(path: dir.appendingPathComponent("src.db").path)
        try AppDatabase.shared.migrator.migrate(source)
        try source.write { db in
            try ProfileEntity(remark: "backup-node", address: "1.2.3.4", port: 443).insert(db)
        }

        let zip = dir.appendingPathComponent("b.zip")
        try BackupHandler.export(to: zip, dbReader: source, defaults: ["someKey": "v", "NSWindow Frame x": "drop", UserDefaults.KEY.v2rayTurnOn.rawValue: true])
        #expect(fm.fileExists(atPath: zip.path))

        let unpacked = try BackupHandler.unpack(zip)
        defer { try? fm.removeItem(at: unpacked.directory) }
        #expect(unpacked.manifest.format == 1)
        #expect(unpacked.manifest.hasDatabase && unpacked.manifest.hasDefaults)
        #expect(unpacked.defaults?["someKey"] as? String == "v")
        #expect(unpacked.defaults?["NSWindow Frame x"] == nil)
        #expect(unpacked.defaults?[UserDefaults.KEY.v2rayTurnOn.rawValue] == nil)

        let restored = try DatabaseQueue(path: dir.appendingPathComponent("dst.db").path)
        try BackupHandler.apply(BackupHandler.Unpacked(manifest: unpacked.manifest, databaseURL: unpacked.databaseURL, defaults: nil, directory: unpacked.directory), dbWriter: restored)
        let remarks = try restored.read { db in try ProfileEntity.fetchAll(db).map(\.remark) }
        #expect(remarks == ["backup-node"])
    }

    @Test func rejectsGarbage() throws {
        let fm = FileManager.default
        let file = fm.temporaryDirectory.appendingPathComponent("not-a-backup-\(UUID().uuidString).zip")
        try Data("hello".utf8).write(to: file)
        defer { try? fm.removeItem(at: file) }
        #expect(throws: (any Error).self) { try BackupHandler.unpack(file) }
    }
}

/// 审查后补的用例
struct ReviewFixTests {
    @Test func tunBlockProcessRuleBecomesRejectOnNewSingbox() {
        let entity = RoutingEntity(name: "custom", remark: "x", block: "process:Ads", proxy: "", direct: "")
        let old = RoutingManager.processRouteRules(for: entity, blockAsReject: false)
        #expect(old.first?.outbound == "block" && old.first?.action == nil)
        let new = RoutingManager.processRouteRules(for: entity, blockAsReject: true)
        #expect(new.first?.outbound == nil && new.first?.action == "reject" && new.first?.process_name == ["Ads"])
    }

    @Test func tunProcessRulesWithoutRoutingDoNotTouchDatabase() {
        let rules = TunConfigHandler.buildProcessRouteRules(directRawValue: "", proxyRawValue: "")
        #expect(rules.allSatisfy { $0.process_path_regex == nil })
    }

    @Test func quickRoutingStripsOtherSpellings() {
        var entity = RoutingEntity(name: "custom", remark: "x", block: "", proxy: "full:example.com", direct: "example.com\ngeoip:cn")
        #expect(QuickRouting.apply(line: "domain:example.com", target: .block, entity: &entity))
        #expect(entity.direct == "geoip:cn")
        #expect(entity.proxy == "")
        #expect(entity.block == "domain:example.com")
    }

    @Test func truncateKeepsInode() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("v2rayu-trunc-\(UUID().uuidString).log").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        try "hello\n".write(toFile: path, atomically: true, encoding: .utf8)
        let before = (try FileManager.default.attributesOfItem(atPath: path))[.systemFileNumber] as? Int
        LogRotation.truncate(path: path)
        let after = (try FileManager.default.attributesOfItem(atPath: path))[.systemFileNumber] as? Int
        #expect(before == after)
        #expect((try FileManager.default.attributesOfItem(atPath: path))[.size] as? Int == 0)
    }
}

/// 单位固定英文, 不随系统语言翻译
struct ByteFormatTests {
    @Test func fixedUnits() {
        #expect(formatBytesFixed(0) == "0 B")
        #expect(formatBytesFixed(250) == "250 B")
        #expect(formatBytesFixed(1500) == "1.50 KB")
        #expect(formatBytesFixed(24_400_000) == "24.4 MB")
        #expect(formatBytesFixed(580_100_000) == "580 MB")
        #expect(formatBytesFixed(1024 * 1024, base: 1024) == "1.00 MB")
        #expect(formatDownloadSpeed(10 * 1024 * 1024) == "10.0 MB/s")
        #expect(SubscriptionUserInfo.formatBytes(107374182400) == "100 GB")
    }
}
