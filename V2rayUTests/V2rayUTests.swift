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
    
    func testBase64() {
      let str = """
vmess://eyJ2IjogIjIiLCAicHMiOiAiIiwgImFkZCI6ICIxMDguMTYwLjEzMS4xMiIsICJwb3J0IjogMjE2OTYsICJhaWQiOiAxNiwgInR5cGUiOiAidXRwIiwgIm5ldCI6ICJrY3AiLCAicGF0aCI6ICIiLCAiaG9zdCI6ICIiLCAiaWQiOiAiNTMxNjVlMWUtNDBjMS0xMWU5LTlmMzEtNTYwMDAxZTA2YzY5IiwgInRscyI6ICJub25lIn0=               
vmess://eyJhZGQiOiJmci5zYW5neXUudHciLCJhaWQiOiIyMzMiLCJncm91cCI6Ind3dy5zc3JzaGFyZS5jb20iLCJob3N0IjoiZnIuc2FuZ3l1LnR3IiwiaWQiOiJjZTE0ZDc4OC0wZjc5LTQ5MWUtODVjYS0wNTI0MDYxMmYyOGEiLCJtcyI6MjM2LCJuZXQiOiJ3cyIsInBhdGgiOiIvIiwicG9ydCI6NDQzLCJwcyI6IkBTU1JPT0xfZnIuc2FuZ3l1LnR3Iiwic3RhdHVzIjoidHJ1ZSIsInRscyI6InRscyIsInR5cGUiOiJub25lIiwidiI6IjIiLCJ2MnJheWlkIjoiNTQ2MTAwMjQtMmE4Ny00NGIxLWJjYjgtMmRkODhkMjVjMWZiIn0=
"""
        print(str.base64Encoded())
        let st1 = "c3NyOi8vTlM0eE1ERXVORGt1TVRrNk1UWTJNRFU2YjNKcFoybHVPbUZsY3kweU5UWXRZMlppT25Cc1lXbHVPbUpWWkZsTlZscHNZV3BHVUZKck9ESXZQM0psYldGeWEzTTlWVEZPVTFaRk9WQlVSamwxWkZkNGMweFVSVEpPYWtFeFQycEJkeVpuY205MWNEMVdNV1JZVEd4T1ZGVnNVbEJVTUhkMVVUQTVUZwpzc3I6Ly9OUzR4TURFdU5Ea3VNVGs2TVRZMk1EUTZiM0pwWjJsdU9tRmxjeTB5TlRZdFkyWmlPbkJzWVdsdU9tSlZaRmxOVmxwc1lXcEdVRkpyT0RJdlAzSmxiV0Z5YTNNOVZURk9VMVpGT1ZCVVJqbDFaRmQ0YzB4VVJUSk9ha0V3VDJwQmVDWm5jbTkxY0QxV01XUllUR3hPVkZWc1VsQlVNSGQxVVRBNVRn".base64Decoded()
        print(st1)
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
