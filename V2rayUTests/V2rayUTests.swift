//
//  V2rayUTests.swift
//  V2rayUTests
//
//  Created by yanue on 2018/10/25.
//  Copyright © 2018 yanue. All rights reserved.
//

import XCTest
@testable import V2rayU
import SwiftyJSON


class V2rayUTests: XCTestCase {
//    override func setUp() {
//        // Put setup code here. This method is called before the invocation of each test method in the class.
//    }
//
//    override func tearDown() {
//        // Put teardown code here. This method is called after the invocation of each test method in the class.
//    }
    func testInbound() {
        var inbound = v2rayInbound()
        inbound.protocol = v2rayProtocol.vmess
        inbound.settingHttp = v2rayInboundHttp()
        inbound.settingSocks = v2rayInboundSock()
        inbound.settingShadowsocks = v2rayInboundShandowsocks()
        inbound.settingVMess = v2rayInboundVMess()
//        inbound.streamSettings = v2rayStreamSettings()

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted //输出格式好看点
        let data = try! encoder.encode(inbound)
        print(String(data: data, encoding: .utf8)!)

    }

    func testOutbound() {
        var outbound = v2rayOutbound()
        outbound.protocol = v2rayProtocolOutbound.vmess
        outbound.settingSocks = v2rayOutboundSocks()
        outbound.settingShadowsocks = v2rayOutboundShadowsocks()
        var v2next = v2rayOutboundVMessItem(
                address: "",
                port: "",
                users: [v2rayOutboundVMessUser(id: "aaa", alterId: 0, level: 0, security: "")]
        )
        outbound.settingVMess = v2rayOutboundVMess(vnext: [v2next])

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted //输出格式好看点
        let data = try! encoder.encode(outbound)
        print(String(data: data, encoding: .utf8)!)

    }

    func testV2ray() {

        return
        var v2ray = v2rayStruct()
        v2ray.inbound = v2rayInbound()
        v2ray.inboundDetour = [v2rayInboundDetour()]
//        var outbound = v2rayOutbound()
        var v2next = v2rayOutboundVMessItem(
                address: "",
                port: "",
                users: [v2rayOutboundVMessUser(id: "aaa", alterId: 0, level: 0, security: "String?")]
        )
        var vmess = v2rayOutboundVMess(
                vnext: [v2next]
        )
//
//        outbound.protocol = .freedom
//        outbound.settings = v2rayOutboundSettings()
////        outbound.settings?.Vmess_vnext = [vmess]
//        outbound.settings?.blackhole_Response = blackhole_Response()

//        print("outbound",outbound)
//        v2ray.outbound = outbound
        v2ray.outboundDetour = [v2rayOutboundDetour()]

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted //输出格式好看点
        let data = try! encoder.encode(v2ray)
        print(String(data: data, encoding: .utf8)!)

    }

    func testDecode() {

    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

        var ming = Person()
        ming.name = "aa"
        ming.profile1 = PersonProfile1()

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted //输出格式好看点
        let data = try! encoder.encode(ming)
        print(String(data: data, encoding: .utf8)!)

//        print(v2ray.toJSONString(prettyPrint:true) ?? "") // 序列化为格式化后的JSON字符串
    }
}
