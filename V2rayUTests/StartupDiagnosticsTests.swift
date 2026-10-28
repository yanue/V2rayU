import Testing
@testable import V2rayU

/// 日志分析: 核心启动失败/崩溃要报错, 不能显示"未发现明显错误" (#1686)
struct LogAnalyzerTests {
    private func labels(_ lines: [String]) -> [LanguageLabel] {
        LogAnalyzer.analyze(lines: lines).compactMap {
            if case .label(let label) = $0 { return label }
            return nil
        }
    }

    @Test(arguments: [
        ("Failed to start: main: failed to load config files: [/Users/x/.V2rayU/config.json] > infra/conf: failed to build outbound config", LanguageLabel.DiagLogCoreStartFailed),
        ("2026/10/27 10:00:00 [Error] app/proxyman/outbound: failed to build outbound handler > some reason", .DiagLogCoreStartFailed),
        ("Failed to start: main: failed to create server > common/uuid: invalid UUID: abc", .DiagLogInvalidUUID),
        ("panic: runtime error: invalid memory address or nil pointer dereference", .DiagLogCorePanic),
        ("[signal SIGSEGV: segmentation violation code=0x2 addr=0x0 pc=0x1]", .DiagLogCorePanic),
        ("fatal error: concurrent map writes", .DiagLogCorePanic),
        ("+0800 2026-10-27 10:00:00 FATAL[0000] start service: initialize outbound[0]: missing password", .DiagLogCoreStartFailed),
        ("FATAL[0000] decode config at /Users/x/.V2rayU/config.json: outbounds[0].server_port: json: cannot unmarshal", .DiagLogCoreStartFailed),
        ("FATAL[0000] decode config at config.json: outbounds[0].uuid: invalid UUID length: 3", .DiagLogInvalidUUID),
    ])
    func fatalPatterns(line: String, expected: LanguageLabel) {
        let result = labels(["Xray 26.5.6 started", line])
        #expect(result.first == expected)
        #expect(!LogAnalyzer.analyze(lines: [line]).contains(.text("未发现明显错误")))
    }

    @Test("Normal log reports no problem")
    func normalLog() {
        let lines = [
            "Xray 26.5.6 (Xray, Penetrates Everything.) Custom (go1.24 darwin/arm64)",
            "2026/10/27 10:00:00 [Warning] core: Xray 26.5.6 started",
            "2026/10/27 10:00:01 [Info] [12345] proxy/socks: TCP Connect request to www.google.com:443",
        ]
        #expect(LogAnalyzer.analyze(lines: lines) == [.text("未发现明显错误")])
    }

    @Test("Panic line is found even when followed by a long goroutine stack")
    func panicBeforeLongStack() {
        let stack = (0 ..< 1000).map { "\tgithub.com/xtls/xray-core/app.func\($0)()" }
        let lines = ["panic: runtime error: index out of range [3] with length 3", "", "goroutine 1 [running]:"] + stack
        #expect(labels(lines) == [.DiagLogCorePanic])
        // 原来只看最后 200 行, panic 那一行会被漏掉
        #expect(LogAnalyzer.analyze(lines: lines, lastLines: 200).first == .label(.DiagLogCorePanic))
    }

    @Test("Same fatal error is reported once, before connection errors")
    func dedupAndOrder() {
        let lines = [
            "2026/10/27 10:00:00 [Info] failed to dial tcp 1.2.3.4:443",
            "Failed to start: main: failed to load config files",
            "Failed to start: main: failed to load config files",
        ]
        let result = LogAnalyzer.analyze(lines: lines)
        #expect(result.first == .label(.DiagLogCoreStartFailed))
        #expect(result.filter { $0 == .label(.DiagLogCoreStartFailed) }.count == 1)
        #expect(result.count == 2)
    }
}

/// 启动前检查节点必填项 (#1694)
struct ProfileValidatorTests {
    private func profile(_ proto: V2rayProtocolOutbound, address: String = "example.com", port: Int = 443,
                         password: String = "secret", encryption: String = "") -> ProfileEntity {
        ProfileEntity(remark: "test", protocol: proto, address: address, port: port, password: password, encryption: encryption)
    }

    @Test(arguments: [V2rayProtocolOutbound.vmess, .vless])
    func uuidRequired(proto: V2rayProtocolOutbound) {
        #expect(ProfileValidator.problem(of: profile(proto, password: "")) == .missingUUID)
        #expect(ProfileValidator.problem(of: profile(proto, password: "  ")) == .missingUUID)
        #expect(ProfileValidator.problem(of: profile(proto, password: "b831381d-6324-4d53-ad4f-8cda48b30811")) == nil)
    }

    @Test(arguments: [V2rayProtocolOutbound.trojan, .shadowsocks, .hysteria2, .anytls])
    func passwordRequired(proto: V2rayProtocolOutbound) {
        #expect(ProfileValidator.problem(of: profile(proto, password: "", encryption: "aes-128-gcm")) == .missingPassword)
        #expect(ProfileValidator.problem(of: profile(proto, password: "pw", encryption: "aes-128-gcm")) == nil)
    }

    @Test("Shadowsocks with method none needs no password")
    func shadowsocksNone() {
        #expect(ProfileValidator.problem(of: profile(.shadowsocks, password: "", encryption: "none")) == nil)
    }

    @Test(arguments: [0, -1, 65536, 100000])
    func invalidPort(port: Int) {
        #expect(ProfileValidator.problem(of: profile(.vless, port: port)) == .invalidPort(port))
    }

    @Test("Empty address")
    func emptyAddress() {
        #expect(ProfileValidator.problem(of: profile(.trojan, address: " ")) == .missingAddress)
    }

    @Test("Local outbounds and optional-auth protocols pass")
    func optionalOrLocal() {
        #expect(ProfileValidator.problem(of: profile(.freedom, address: "", port: 0, password: "")) == nil)
        #expect(ProfileValidator.problem(of: profile(.socks, password: "")) == nil)
        #expect(ProfileValidator.problem(of: profile(.http, password: "")) == nil)
    }

    @Test("First invalid member of a combination is reported")
    func firstFailure() {
        let ok = profile(.vless)
        var bad = profile(.trojan, password: "")
        bad.remark = "bad"
        let failure = ProfileValidator.firstFailure(in: [ok, bad, profile(.vmess, password: "")])
        #expect(failure?.profile.remark == "bad")
        #expect(failure?.problem == .missingPassword)
        #expect(ProfileValidator.firstFailure(in: [ok]) == nil)
    }

    @Test("Display name falls back to address:port")
    func displayName() {
        var p = profile(.vless)
        p.remark = ""
        #expect(ProfileValidator.displayName(of: p) == "example.com:443")
    }

    @MainActor
    @Test("Message names the profile")
    func messageNamesProfile() {
        let p = ProfileEntity(remark: "HK-01", protocol: .vless, address: "a.com", port: 443, password: "")
        let message = ProfileValidator.message(for: ProfileValidator.Failure(profile: p, problem: .missingUUID))
        #expect(message.contains("HK-01"))
        #expect(message.contains("UUID"))
    }
}
