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
        var inbound = V2rayInbound()
        inbound.protocol = V2rayProtocolInbound.vmess
        inbound.settingHttp = V2rayInboundHttp()
        inbound.settingSocks = V2rayInboundSocks()
        inbound.settingShadowsocks = V2rayInboundShadowsocks()
        inbound.settingVMess = V2rayInboundVMess()
//        inbound.streamSettings = V2rayStreamSettings()

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted //输出格式好看点
        let data = try! encoder.encode(inbound)
        print(String(data: data, encoding: .utf8)!)

    }

    func testOutbound() {
        var outbound = V2rayOutbound()
        outbound.protocol = V2rayProtocolOutbound.vmess
        outbound.settingSocks = V2rayOutboundSocks()
        outbound.settingShadowsocks = V2rayOutboundShadowsocks()
        let v2next = V2rayOutboundVMessItem(
                address: "",
                port: "",
                users: [V2rayOutboundVMessUser(id: "aaa", alterId: 0, level: 0, security: "")]
        )
        outbound.settingVMess = V2rayOutboundVMess(vnext: [v2next])

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted //输出格式好看点
        let data = try! encoder.encode(outbound)
        print(String(data: data, encoding: .utf8)!)

    }

    func testV2ray() {
        let V2rayCfg = V2rayConfig()
        let errmsg = V2rayCfg.saveByJson(jsonText: jsonTxt)
        if errmsg != "" {
            print("err:", errmsg)
            return
        }
        let encoder = JSONEncoder()
//        encoder.outputFormatting = .sortedKeys
        encoder.outputFormatting = .prettyPrinted //输出格式好看点
        let data = try! encoder.encode(V2rayCfg.v2ray)
        print(String(data: data, encoding: .utf8)!)
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

//        print(V2ray.toJSONString(prettyPrint:true) ?? "") // 序列化为格式化后的JSON字符串
    }
}
