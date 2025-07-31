//
//  HevTun.swift
//  V2rayU
//
//  Created by yanue on 2024/12/24.
//

import Foundation
import NetworkExtension
import Tun2SocksKit

extension V2rayLaunch {
    static let tunUpScriptPath: String = AppHomePath + "/tun_up.sh"
    static let tunDownScriptPath: String = AppHomePath + "/tun_down.sh"

    static let stringConfigTemplate = """
    tunnel:
      mtu: 9000
      name: utun99
    
    socks5:
      # Socks5 server port
      port: {{ socksPort }}
      # Socks5 server address (ipv4/ipv6)
      address: 127.0.0.1
      # Socks5 UDP relay mode (tcp|udp)
      udp: 'tcp'

    misc:
      task-stack-size: 20480
      connect-timeout: 5000
      read-write-timeout: 60000
      log-file: stderr
      log-level: debug
      limit-nofile: 65535
    """
    
    static let tunUpScriptContent = """
    #!/bin/bash
    # Bypass upstream socks5 server
    # 10.0.0.1: socks5 server
    # 10.0.2.2: default gateway
    sudo route add -net 10.0.0.1/32 10.0.2.2
    # Route others
    sudo route change -inet default -interface utun99
    sudo route change -inet6 default -interface utun99
    """
    
    static let tunDownScriptContent = """
    #!/bin/bash
    sudo route delete -net 10.0.0.1/32 10.0.2.2
    sudo route delete -inet default -interface utun99
    sudo route delete -inet6 default -interface utun99
    """
    
    static func runTun2Socks() {
        // Write and configure scripts
//        createScript(at: tunUpScriptPath, content: tunUpScriptContent)
//        createScript(at: tunDownScriptPath, content: tunDownScriptContent)
        
        // Replace placeholders in configuration
        let stringConfigContent = stringConfigTemplate
            .replacingOccurrences(of: "{{ tun_up_sh }}", with: tunUpScriptPath)
            .replacingOccurrences(of: "{{ tun_down_sh }}", with: tunDownScriptPath)
            .replacingOccurrences(of: "{{ socksPort }}", with: "1080") // Example port
        print("Tun2Socks config: \(stringConfigContent)")
        sleep(10)
        // Run Tun2Socks
        Socks5Tunnel.run(withConfig: .string(content: stringConfigContent)) { code in
            print("Tun2Socks exited with code: \(code)")
            logStats()
        }
    }
    
    static func stopTun2Socks() {
        Socks5Tunnel.quit()
    }

    // Create script and set executable permissions
    private static func createScript(at path: String, content: String) {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            // Add executable permission
            let doSh = "cd " + AppHomePath + " && sudo chown root:admin ./tun_*.sh && sudo chmod a+rsx ./tun_*.sh"
            // Create authorization reference for the user
            executeAppleScriptWithOsascript(script: doSh)
        } catch {
            print("Failed to create script at \(path): \(error)")
        }
    }

    // 打印统计信息
    static func logStats() {
        let timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            // 创建新的 Task 来执行异步操作
            Task {
                let updatedStats = Socks5Tunnel.stats
                print("Tun2Socks updated stats: \(updatedStats)")
            }
        }
        // 将 timer 添加到当前 RunLoop
        RunLoop.current.add(timer, forMode: .common)
    }
}
