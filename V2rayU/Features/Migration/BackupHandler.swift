//
//  BackupHandler.swift
//  V2rayU
//
//  配置备份 / 恢复: 数据库 (节点、订阅、路由、组合) + UserDefaults (设置、快捷键) 打成一个 zip, 换机器直接导入
//

import AppKit
import Foundation
import GRDB

struct BackupManifest: Codable, Equatable {
    var format = 1
    var appVersion: String
    var createdAt: Date
    var hasDatabase: Bool
    var hasDefaults: Bool
}

enum BackupHandler {
    static let databaseFileName = "V2rayU.db"
    static let defaultsFileName = "defaults.plist"
    static let manifestFileName = "manifest.json"
    static let fileExtension = "zip"

    /// 这些键是本机运行状态, 不该带到别的机器上
    static let excludedDefaultKeys: Set<String> = [
        UserDefaults.KEY.v2rayTurnOn.rawValue,
        UserDefaults.KEY.runningProfile.rawValue,
        UserDefaults.KEY.capabilityRulesUpdateDate.rawValue,
        UserDefaults.KEY.ruleSetUpdateDate.rawValue,
        UserDefaults.KEY.backupLastExport.rawValue,
    ]

    static var lastExportDate: Date? {
        let t = UserDefaults.standard.double(forKey: UserDefaults.KEY.backupLastExport.rawValue)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    static func currentDefaults() -> [String: Any] {
        let bundleId = Bundle.main.bundleIdentifier ?? "net.yanue.V2rayU"
        let all = UserDefaults.standard.persistentDomain(forName: bundleId) ?? [:]
        return filterDefaults(all)
    }

    /// 去掉运行状态键和系统自己写进去的 NS* / Apple* 键
    static func filterDefaults(_ all: [String: Any]) -> [String: Any] {
        all.filter { key, _ in
            !excludedDefaultKeys.contains(key) && !key.hasPrefix("NS") && !key.hasPrefix("Apple") && !key.hasPrefix("com.apple")
        }
    }

    // MARK: - 导出

    /// 导出到 zip; 返回写好的文件路径
    @discardableResult
    static func export(to destination: URL, dbReader: any DatabaseReader = AppDatabase.shared.reader,
                       defaults: [String: Any] = currentDefaults()) throws -> URL {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("v2rayu-backup-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        // SQLite 在线备份: 连接开着也能拷出一致的快照
        let dbCopy = try DatabaseQueue(path: work.appendingPathComponent(databaseFileName).path)
        try dbReader.backup(to: dbCopy)
        try dbCopy.close()

        var hasDefaults = false
        let filtered = filterDefaults(defaults)
        if !filtered.isEmpty {
            let data = try PropertyListSerialization.data(fromPropertyList: filtered, format: .xml, options: 0)
            try data.write(to: work.appendingPathComponent(defaultsFileName))
            hasDefaults = true
        }

        let manifest = BackupManifest(appVersion: getAppVersion(), createdAt: Date(), hasDatabase: true, hasDefaults: hasDefaults)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: work.appendingPathComponent(manifestFileName))

        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try zip(directory: work, to: destination)
        return destination
    }

    // MARK: - 导入

    struct Unpacked {
        var manifest: BackupManifest
        var databaseURL: URL?
        var defaults: [String: Any]?
        var directory: URL
    }

    /// 解包并校验, 不改任何东西
    static func unpack(_ archive: URL) throws -> Unpacked {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("v2rayu-restore-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        try unzip(archive, to: work)

        // zip 里可能多一层目录
        var root = work
        if !fm.fileExists(atPath: root.appendingPathComponent(manifestFileName).path),
           let sub = try fm.contentsOfDirectory(at: work, includingPropertiesForKeys: nil).first(where: {
               fm.fileExists(atPath: $0.appendingPathComponent(manifestFileName).path)
           }) {
            root = sub
        }
        let manifestData = try Data(contentsOf: root.appendingPathComponent(manifestFileName))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(BackupManifest.self, from: manifestData)
        guard manifest.format == 1 else {
            throw NSError(domain: "BackupHandler", code: 2, userInfo: [NSLocalizedDescriptionKey: "unsupported backup format \(manifest.format)"])
        }

        var dbURL: URL? = nil
        if manifest.hasDatabase {
            let url = root.appendingPathComponent(databaseFileName)
            // 打开一下确认是合法的 SQLite 且有 profile 表
            let probe = try DatabaseQueue(path: url.path)
            let ok = try probe.read { db in try db.tableExists(ProfileEntity.databaseTableName) }
            try probe.close()
            guard ok else {
                throw NSError(domain: "BackupHandler", code: 3, userInfo: [NSLocalizedDescriptionKey: "backup database has no profile table"])
            }
            dbURL = url
        }

        var defaults: [String: Any]? = nil
        if manifest.hasDefaults {
            let data = try Data(contentsOf: root.appendingPathComponent(defaultsFileName))
            defaults = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        }
        return Unpacked(manifest: manifest, databaseURL: dbURL, defaults: defaults, directory: work)
    }

    /// 把备份写进当前数据库和 UserDefaults. 调用方负责先停核心、之后刷新界面
    static func apply(_ unpacked: Unpacked, dbWriter: any DatabaseWriter = AppDatabase.shared.dbWriter) throws {
        defer { try? FileManager.default.removeItem(at: unpacked.directory) }
        if let dbURL = unpacked.databaseURL {
            let source = try DatabaseQueue(path: dbURL.path)
            // 在线恢复: 直接覆盖当前库的页, 不用关连接换文件
            try source.backup(to: dbWriter)
            try source.close()
            // 备份可能来自老版本, 补跑迁移
            try AppDatabase.shared.migrator.migrate(dbWriter)
        }
        if let defaults = unpacked.defaults {
            let bundleId = Bundle.main.bundleIdentifier ?? "net.yanue.V2rayU"
            var merged = UserDefaults.standard.persistentDomain(forName: bundleId) ?? [:]
            for (k, v) in filterDefaults(defaults) { merged[k] = v }
            UserDefaults.standard.setPersistentDomain(merged, forName: bundleId)
            UserDefaults.standard.synchronize()
        }
    }

    // MARK: - UI 入口

    @MainActor
    static func exportWithPanel() {
        let panel = NSSavePanel()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        panel.nameFieldStringValue = "V2rayU-backup-\(formatter.string(from: Date())).\(fileExtension)"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try export(to: url)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: UserDefaults.KEY.backupLastExport.rawValue)
            noticeTip(title: String(localized: .BackupExport), informativeText: url.lastPathComponent)
        } catch {
            alertDialog(title: String(localized: .BackupExport), message: error.localizedDescription)
        }
    }

    @MainActor
    static func importWithPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let unpacked: Unpacked
        do {
            unpacked = try unpack(url)
        } catch {
            alertDialog(title: String(localized: .BackupImport), message: error.localizedDescription)
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: .BackupImport)
        alert.informativeText = String(localized: .BackupImportConfirm) + "\n\n\(unpacked.manifest.appVersion)  \(Int(unpacked.manifest.createdAt.timeIntervalSince1970).formattedDate)"
        alert.addButton(withTitle: String(localized: .Confirm))
        alert.addButton(withTitle: String(localized: .Cancel))
        guard alert.runModal() == .alertFirstButtonReturn else {
            try? FileManager.default.removeItem(at: unpacked.directory)
            return
        }

        Task {
            let wasOn = AppState.shared.v2rayTurnOn
            if wasOn { await V2rayLaunch.shared.stop() }
            do {
                try apply(unpacked)
            } catch {
                alertDialog(title: String(localized: .BackupImport), message: error.localizedDescription)
                if wasOn { await V2rayLaunch.shared.start() }
                return
            }
            AppSettings.shared.reload()
            // 数据库整个换了, 本机原来选中的节点多半不在里面: 不在就改选导入后的第一个节点, 不然重新启动会失败
            let current = UserDefaults.get(forKey: .runningProfile, defaultValue: "")
            let profile = ProfileStore.shared.fetchOne(uuid: current) ?? ProfileStore.shared.fetchAll().first
            AppState.shared.runningProfile = profile?.uuid ?? ""
            AppState.shared.runningServer = profile
            AppState.shared.runningRouting = UserDefaults.get(forKey: .runningRouting, defaultValue: "")
            await AppMenuManager.shared.refreshServerItems()
            AppMenuManager.shared.refreshRoutingItems()
            await SubscriptionScheduler.shared.refreshAll()
            noticeTip(title: String(localized: .BackupImport), informativeText: String(localized: .BackupImportDone))
            if wasOn { await V2rayLaunch.shared.start() }
        }
    }

    // MARK: - zip

    private static func zip(directory: URL, to destination: URL) throws {
        try run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", directory.path, destination.path])
    }

    private static func unzip(_ archive: URL, to directory: URL) throws {
        try run("/usr/bin/ditto", ["-x", "-k", archive.path, directory.path])
    }

    private static func run(_ path: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        let err = Pipe()
        p.standardError = err
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw NSError(domain: "BackupHandler", code: Int(p.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "\(path) failed: \(msg)"])
        }
    }
}
