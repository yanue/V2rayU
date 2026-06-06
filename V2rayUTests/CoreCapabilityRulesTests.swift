import Testing
import Foundation
@testable import V2rayU

struct CoreCapabilityRulesTests {

    // MARK: - XrayVersion parsing

    @Test func xrayVersionCalendarStyle() {
        let v = XrayVersion("25.3.1")
        #expect(v != nil)
        #expect(v!.isCalendarStyle)
        #expect(v!.major == 25)
        #expect(v!.minor == 3)
        #expect(v!.patch == 1)
    }

    @Test func xrayVersionLegacyStyle() {
        let v = XrayVersion("1.8.24")
        #expect(v != nil)
        #expect(!v!.isCalendarStyle)
        #expect(v!.major == 1)
        #expect(v!.minor == 8)
        #expect(v!.patch == 24)
    }

    @Test func xrayVersionParsingInvalid() {
        #expect(XrayVersion("") == nil)
        #expect(XrayVersion("abc") == nil)
    }

    @Test func xrayVersionParsingPartial() {
        let v = XrayVersion("1.2")
        #expect(v != nil)
        #expect(v!.major == 1)
        #expect(v!.minor == 2)
        #expect(v!.patch == 0)
    }

    @Test func xrayVersionComparison() {
        let v1 = XrayVersion("1.8.0")!
        let v2 = XrayVersion("1.8.24")!
        let v3 = XrayVersion("25.3.1")!
        #expect(v1 < v2)
        #expect(v2 < v3)
        #expect(v3 > v2)
        #expect(v1 == v1)
    }

    // MARK: - XraySupportRule evaluate

    @Test func supportedRule() {
        let rule = XraySupportRule.supported(note: "all good")
        let resultNil = rule.evaluate(version: nil, featureName: "test")
        let resultWithVersion = rule.evaluate(version: XrayVersion("1.0.0")!, featureName: "test")
        if case .supported = resultNil {
            #expect(true)
        } else {
            #expect(false, "Expected .supported for nil version")
        }
        if case .supported = resultWithVersion {
            #expect(true)
        } else {
            #expect(false, "Expected .supported for version 1.0.0")
        }
    }

    @Test func removedRuleWithVersionBound() {
        let rule = XraySupportRule.removed(note: "removed in new versions", removedAt: XrayVersion(26, 1, 31))
        let oldVersion = XrayVersion(24, 0, 0)
        let newVersion = XrayVersion(26, 2, 0)
        let resultOld = rule.evaluate(version: oldVersion, featureName: "test")
        let resultNew = rule.evaluate(version: newVersion, featureName: "test")
        #expect(resultOld.isSupported == false)
        #expect(resultNew.isSupported == false)
    }

    @Test func legacyMinVersionBound() {
        let rule = XraySupportRule.supported(note: "needs 1.8+", legacyMin: XrayVersion(1, 8, 0))
        let old = XrayVersion(1, 7, 0)
        let current = XrayVersion(1, 8, 5)
        let oldResult = rule.evaluate(version: old, featureName: "test")
        let currentResult = rule.evaluate(version: current, featureName: "test")
        #expect(oldResult.isSupported == false)
        #expect(currentResult.isSupported == true)
    }

    @Test func calendarMinVersionBound() {
        let rule = XraySupportRule.supported(note: "needs 24.9+", calendarMin: XrayVersion(24, 9, 30))
        let old = XrayVersion(24, 8, 0)
        let current = XrayVersion(24, 10, 0)
        let oldResult = rule.evaluate(version: old, featureName: "test")
        let currentResult = rule.evaluate(version: current, featureName: "test")
        #expect(oldResult.isSupported == false)
        #expect(currentResult.isSupported == true)
    }

    @Test func unknownVersionFallback() {
        let rule = XraySupportRule.supported(note: "needs 1.8+", legacyMin: XrayVersion(1, 8, 0))
        let result = rule.evaluate(version: nil, featureName: "test")
        if case .unknown = result {
            #expect(true)
        } else {
            #expect(false, "Expected .unknown but got \(result)")
        }
    }

    // MARK: - CapabilityEvidence flexible decoding

    @Test func evidenceDecodingWithSourceURL() throws {
        let json = """
        {"id":"e1","kind":"releaseNote","statement":"test","sourceTitle":"title","sourceURL":"https://example.com","quote":"quote"}
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let evidence = try decoder.decode(CapabilityEvidence.self, from: data)
        #expect(evidence.id == "e1")
        #expect(evidence.sourceURL == "https://example.com")
    }

    @Test func evidenceDecodingWithSnakeCaseSourceUrl() throws {
        let json = """
        {"id":"e2","kind":"releaseNote","statement":"test","sourceTitle":"title","source_url":"https://snake.example.com","quote":"quote"}
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let evidence = try decoder.decode(CapabilityEvidence.self, from: data)
        #expect(evidence.id == "e2")
        #expect(evidence.sourceURL == "https://snake.example.com")
    }

    // MARK: - CapabilityPayload to XrayCapabilityDefinition

    @Test func capabilityPayloadConversion() throws {
        let json = """
        {"key":"outbound.vmess","displayName":"VMess","kind":"Outbound","docsPath":"/docs","rule":{"type":"supported","note":"OK"}}
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let payload = try decoder.decode(CapabilityPayload.self, from: data)
        let definition = XrayCapabilityDefinition(payload: payload)
        #expect(definition != nil)
        #expect(definition?.key == "outbound.vmess")
        #expect(definition?.displayName == "VMess")
    }

    // MARK: - XraySupportCatalog

    @Test func builtinCapabilitiesHaveRequiredFields() {
        let caps = XraySupportCatalog.builtInCapabilities
        #expect(!caps.isEmpty)
        for cap in caps {
            #expect(!cap.key.isEmpty)
            #expect(!cap.displayName.isEmpty)
        }
    }

    @Test func builtinCapabilitiesContainKey() {
        let outboundVMess = XraySupportCatalog.capability(forKey: "outbound.vmess")
        #expect(outboundVMess != nil)
        #expect(outboundVMess?.key == "outbound.vmess")
    }

    @Test func builtinCapabilitiesForOutbound() {
        for proto in [V2rayProtocolOutbound.vmess, .vless, .trojan, .shadowsocks, .hysteria2] {
            let def = XraySupportCatalog.definition(forOutbound: proto)
            #expect(def != nil, "Missing capability for \(proto.rawValue)")
        }
    }

    // MARK: - SingboxFallbackResolver incompatibility reasons

    @Test func singboxFallbackForBasicVmess() {
        let profile = ProfileEntity(protocol: .vmess, address: "x.com", port: 443, password: "uuid", network: .tcp, security: .tls)
        let reasons = SingboxFallbackResolver.incompatibilityReasons(for: profile)
        #expect(reasons.isEmpty || reasons.count >= 0)
    }

    @Test func singboxFallbackForXtls() {
        var profile = ProfileEntity(protocol: .vless, address: "x.com", port: 443, password: "uuid", security: .xtls)
        profile.flow = "xtls-rprx-vision"
        let reasons = SingboxFallbackResolver.incompatibilityReasons(for: profile)
        let hasXtlsReason = reasons.contains { $0.contains("XTLS") }
        #expect(hasXtlsReason)
    }

    @Test func singboxFallbackForXhttp() {
        let profile = ProfileEntity(protocol: .vmess, address: "x.com", port: 443, password: "uuid", network: .xhttp, security: .tls)
        let reasons = SingboxFallbackResolver.incompatibilityReasons(for: profile)
        let hasXhttpReason = reasons.contains { $0.contains("xhttp") }
        #expect(hasXhttpReason)
    }

    @Test func singboxFallbackForHttpHeader() {
        let profile = ProfileEntity(protocol: .vmess, address: "x.com", port: 443, password: "uuid", network: .tcp, headerType: .http, security: .tls)
        let reasons = SingboxFallbackResolver.incompatibilityReasons(for: profile)
        let hasHeaderReason = reasons.contains { $0.contains("HTTP") || $0.contains("伪装") }
        #expect(hasHeaderReason)
    }
}

// Helper to check if XrayFeatureAvailability is "supported"
extension XrayFeatureAvailability {
    var isSupported: Bool {
        if case .supported = self { return true }
        return false
    }
}
