//
//  ping.swift
//  V2rayU
//
//  Created by Erick on 2019/10/30.
//  Copyright © 2019 yanue. All rights reserved.
//

import SwiftyJSON

// ping and choose fastest v2ray
var inPing = false
var fastV2rayName = ""
var fastV2raySpeed = 5
let pingJsonFileName = "ping.json"
let pingJsonFilePath = AppHomePath + "/" + pingJsonFileName
var task: Process?

struct pingItem: Codable {
    var name: String = ""
    var host: String = ""
    var ping: String = ""
}

class PingSpeed: NSObject {

    var pingServers: [V2rayItem] = []
    var serverLen : Int = 0

    func pingAll() {
        print("ping start")
        if inPing {
            print("ping inPing")
            return
        }
        fastV2rayName = ""
        self.pingServers = []
        let itemList = V2rayServer.list()
        if itemList.count == 0 {
            return
        }
        let langStr = Locale.current.languageCode
        var pingTip: String = ""
        if UserDefaults.getBool(forKey: .autoSelectFastestServer) {
            if langStr == "en" {
                pingTip = "Ping Speed - In Testing(Choose fastest server)"
            } else {
                pingTip = "Ping Speed - 测试中(选择最快服务器)"
            }
        } else {
            if langStr == "en" {
                pingTip = "Ping Speed - In Testing "
            } else {
                pingTip = "Ping Speed - 测试中"
            }
        }
        menuController.statusMenu.item(withTag: 1)?.title = pingTip
        // in ping
        inPing = true
        self.serverLen = itemList.count
        for item in itemList {
            self.pingEachServer(item: item)
        }
    }

    func pingEachServer(item: V2rayItem) {
        if !item.isValid {
            self.pingServers.append(item)
            return
        }
        let host = self.parseHost(item: item)
        guard let _ = NSURL(string: host) else {
            print("not host", host)
            return
        }
        // print("item", item.remark, host, item.url)
        // Ping once
        var ping: SwiftyPing?
        do {
            ping = try SwiftyPing(host: host, configuration: PingConfiguration(interval: 1.0, with: 1), queue: DispatchQueue.global())
            ping?.finished = { (result) in
                DispatchQueue.main.async {
                    var message = "\n--- \(host) ping statistics ---\n"
                    message += "\(result.packetsTransmitted) transmitted, \(result.packetsReceived) received"
                    if let loss = result.packetLoss {
                        message += String(format: "\n%.1f%% packet loss\n", loss * 100)
                    } else {
                        message += "\n"
                    }
                    if let roundtrip = result.roundtrip {
                        item.speed = String(format: "%d", Int(roundtrip.average * 1000)) + "ms"
                        item.store()
                        message += String(format: "round-trip min/avg/max/stddev = %.3f/%.3f/%.3f/%.3f ms", roundtrip.minimum * 1000, roundtrip.average * 1000, roundtrip.maximum * 1000, roundtrip.standardDeviation * 1000)
                    }
                    //print("finished",message)
                    self.pingServers.append(item)
                    self.refreshStatusMenu()
                }
            }
            ping?.targetCount = 5
            try ping?.startPinging()
        } catch {
            print("ping ",item.name,host,error.localizedDescription)
        }
    }

    func refreshStatusMenu() {
        if self.pingServers.count == self.serverLen {
            inPing = false
            menuController.statusMenu.item(withTag: 1)?.title = "Ping Speed..."
            menuController.showServers()
            // reload config
            if menuController.configWindow != nil {
                menuController.configWindow.serversTableView.reloadData()
            }
        }
    }

    func pingInCmd() {
        let cmd = "cd " + AppHomePath + " && chmod +x ./V2rayUHelper && ./V2rayUHelper -cmd ping -t 5s -f ./" + pingJsonFileName
        //        print("cmd", cmd)
        let res = runShell(launchPath: "/bin/bash", arguments: ["-c", cmd])

        NSLog("pingInCmd: res=(\(String(describing: res))) cmd=(\(cmd))")

        // 这里直接判断ok有问题，res里面还有lookup
        if res?.contains("ok config.") ?? false {
            // res is: ok config.xxxx
            fastV2rayName = res!.replacingOccurrences(of: "ok ", with: "")
        }
    }

    func parsePingResult() {
        let jsonText = try? String(contentsOfFile: pingJsonFilePath, encoding: String.Encoding.utf8)
        guard let json = try? JSON(data: (jsonText ?? "").data(using: String.Encoding.utf8, allowLossyConversion: false)!) else {
            return
        }

        var pingResHash: Dictionary<String, String> = [:]
        if json.arrayValue.count > 0 {
            for val in json.arrayValue {
                let name = val["name"].stringValue
                let ping = val["ping"].stringValue
                pingResHash[name] = ping
            }
        }

        let itemList = V2rayServer.list()
        if itemList.count == 0 {
            return
        }

        for item in itemList {
            if !item.isValid {
                continue
            }
            let x = pingResHash[item.name]
            if x != nil && x!.count > 0 {
                item.speed = x!
                item.store()
            }
        }
    }

    func parseHost(item: V2rayItem) -> (String) {
        let cfg = V2rayConfig()
        cfg.parseJson(jsonText: item.json)

        var host: String = ""
        var port: Int
        if cfg.serverProtocol == V2rayProtocolOutbound.vmess.rawValue {
            host = cfg.serverVmess.address
            port = cfg.serverVmess.port
        }
        if cfg.serverProtocol == V2rayProtocolOutbound.vless.rawValue {
            host = cfg.serverVless.address
            port = cfg.serverVless.port
        }
        if cfg.serverProtocol == V2rayProtocolOutbound.shadowsocks.rawValue {
            host = cfg.serverShadowsocks.address
            port = cfg.serverShadowsocks.port
        }
        if cfg.serverProtocol == V2rayProtocolOutbound.trojan.rawValue {
            host = cfg.serverTrojan.address
            port = cfg.serverTrojan.port
        }
        if cfg.serverProtocol == V2rayProtocolOutbound.socks.rawValue {
            if cfg.serverSocks5.servers.count == 0 {
                return ""
            }
            host = cfg.serverSocks5.servers[0].address
            port = Int(cfg.serverSocks5.servers[0].port)
        }

        return host
    }

    func runShell(launchPath: String, arguments: [String]) -> String? {
        task = Process()
        task?.launchPath = launchPath
        task?.arguments = arguments

        let pipe = Pipe()
        task?.standardOutput = pipe
        task?.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: String.Encoding.utf8)!

        if output.count > 0 {
            //remove newline character.
            let lastIndex = output.index(before: output.endIndex)
            return String(output[output.startIndex..<lastIndex])
        }

        return output
    }
}
