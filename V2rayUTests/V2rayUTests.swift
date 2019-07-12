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
    
    func testImportVmess() {
        let url = "vmess://eyJhZGQiOiJhLnYycmF5LndvcmxkIiwiYWRkZGF0ZSI6bnVsbCwiYWlkIjoiNjQiLCJjb3VudHJ5IjpudWxsLCJkYXRhIjpudWxsLCJlcnJvcmNvdW50IjpudWxsLCJob3N0IjoiIiwiaWQiOiJjNzYwYTkzYi1iNjUyLTQ0YTAtOTdkOC0yNGI3YTg4OWM5MmMiLCJtX3N0YXRpb25fY25fbXMiOm51bGwsIm1fc3RhdGlvbl9jbl9zdGF0dXMiOm51bGwsIm1zIjpudWxsLCJuZXQiOiJoMiIsInBhdGgiOiIvZmdxIiwicG9ydCI6NDQzLCJwcyI6IlNTUlNIQVJFLkNPTSIsInN0YXR1cyI6bnVsbCwidGxzIjoidGxzIiwidHlwZSI6Im5vbmUiLCJ2IjoiMiJ9"
        let importUri = ImportUri()
        importUri.importVmessUri(uri: url)
        print("vmess1", importUri.error, importUri.json)
    }
    

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
                port: 0,
                users: [V2rayOutboundVMessUser(id: "aaa", alterId: 0, level: 0, security: "")]
        )
        outbound.settingVMess = V2rayOutboundVMess(vnext: [v2next])

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted //输出格式好看点
        let data = try! encoder.encode(outbound)
        print(String(data: data, encoding: .utf8)!)

    }

    func testV2ray() {
        let v2rayCfg = V2rayConfig()
        v2rayCfg.parseJson(jsonText: jsonTxt)
        if v2rayCfg.errors.count > 0 {
            print("err:", v2rayCfg.errors)
            return
        }

        v2rayCfg.isNewVersion = false;
        v2rayCfg.httpPort = "8080"
        v2rayCfg.socksPort = "1990"

        print("js", v2rayCfg.combineManual())
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
    
    func testUrl(){
        let url = "http://奥/奥神队"
        let charSet = NSMutableCharacterSet()
        charSet.formUnion(with: CharacterSet.urlQueryAllowed)
        charSet.addCharacters(in: "#")
        let url1 = url.addingPercentEncoding(withAllowedCharacters:  charSet as CharacterSet)!
        print("url1",url1);
        guard let rUrl = URL(string: url1) else {
            print("not url")
            return
        }
        if rUrl.scheme == nil || rUrl.host == nil {
            print("not url 1")
        }
        print("url",rUrl.scheme,rUrl.host,rUrl.baseURL,rUrl.path)

    }
}
