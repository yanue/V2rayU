//
//  QA.swift
//  V2rayU
//
//  Created by yanue on 2025/9/13.
//

import SwiftUI

struct QAView: View {
    @ObservedObject private var lm = LanguageManager.shared
    @State private var expandedIndices: Set<Int> = []

    private struct QAItem: Identifiable {
        let id = UUID()
        let question: String
        let answer: String
    }
    
    private var items: [QAItem] {
        switch lm.selectedLanguage {
        case .zhHans:
            return [
                QAItem(question: "V2rayU 是如何工作的？", answer: """
                V2rayU 是一个基于 V2Ray 核心的 macOS 应用，提供图形界面来简化 V2Ray 的配置与管理。它使用 launchd 启动并管理 V2Ray 进程，并为其设置系统代理以实现代理上网功能。
                """),
                QAItem(question: "配置文件存储在哪里？", answer: """
                V2rayU 的配置文件存储在用户主目录下的 ~/.V2rayU/ 目录中(~代表用户名)，可在命令行执行 ls -al ~/.V2rayU/ 查看文件明细。
                
                文件说明:
                ~/.V2rayU/config.json - v2ray-core主要配置文件
                ~/.V2rayU/V2rayUTool - 重要!!! 系统代理设置的辅助工具, 必须要有 -rwsrwsrwx 1 root admin 权限
                ~/.V2rayU/.V2rayU.db - 5.0以上版本的 SQLite 数据库，存储订阅和服务器信息
                ~/.V2rayU/v2ray-core/v2ray - 运行的 v2ray-core 可执行文件, 需对应系统架构版本 (x86_64 或 arm64)
                ~/.V2rayU/proxy.js - Pac 模式下的自动代理配置文件
                ~/.V2rayU/v2ray-core.log - v2ray-core 日志
                """),
                QAItem(question: "运行模式说明", answer: """
                主要是怎么设置系统代理:
                Pac 模式：系统设置pac代理(设置->网络->WIFI->详情->代理->自动代理配置)
                Global 模式：系统设置http/socks代理(设置->网络->WIFI->详情->代理->HTTP,HTTPS和SOCKS代理)
                Manual 模式：手动模式,不设置系统代理(会清理系统代理,包括pac,HTTP,HTTPS,SOCKS代理)
                说明: 以上主要是以浏览器等系统级应用会走系统代理，其他应用通常需要手动设置代理。
                """),
                QAItem(question: "运行模式与路由的关系", answer: """
                运行模式决定了系统代理的设置方式，而路由规则则决定了哪些流量通过代理服务器，哪些流量直连。两者结合使用，可以实现灵活的网络访问策略。
                """),
                QAItem(question: "路由匹配优先级", answer: """
                路由匹配优先级: 域名阻断 -> 域名代理 -> 域名直连 -> IP阻断 -> IP代理 -> IP直连
                """),
                QAItem(question: "如何实现真全局代理？", answer: """
                默认情况除浏览器外的应用通常需要手动配置代理设置。如果想实现真全局代理，可以考虑使用第三方工具如 Proxifier 来强制所有应用走代理。
                """),
                QAItem(question: "如何手动更新 core", answer: """
                可以手动下载 xray-core 对应系统架构版本替换到 ~/.V2rayU/v2ray-core/ 目录下，请注意，需要更改 core 名称为 ~/.V2rayU/v2ray-core/v2ray
                """),
            ]
        case .zhHant:
            return [
                QAItem(question: "V2rayU 是如何運作的？", answer: """
                V2rayU 是一個基於 V2Ray 核心的 macOS 應用，提供圖形介面來簡化 V2Ray 的設定與管理。它使用 launchd 啟動並管理 V2Ray 行程，並為其設定系統代理以實現代理上網功能。
                """),
                QAItem(question: "設定檔儲存在哪裡？", answer: """
                V2rayU 的設定檔儲存在使用者主目錄下的 ~/.V2rayU/ 目錄中 (~ 代表使用者名稱)，可在終端機執行 ls -al ~/.V2rayU/ 查看檔案明細。
                
                檔案說明:
                ~/.V2rayU/config.json - v2ray-core 主要設定檔
                ~/.V2rayU/V2rayUTool - 重要!!! 系統代理設定的輔助工具，必須要有 -rwsrwsrwx 1 root admin 權限
                ~/.V2rayU/.V2rayU.db - 5.0 以上版本的 SQLite 資料庫，儲存訂閱與伺服器資訊
                ~/.V2rayU/v2ray-core/v2ray - 執行的 v2ray-core 可執行檔，需對應系統架構版本 (x86_64 或 arm64)
                ~/.V2rayU/proxy.js - Pac 模式下的自動代理設定檔
                ~/.V2rayU/v2ray-core.log - v2ray-core 日誌
                """),
                QAItem(question: "運行模式說明", answer: """
                主要是如何設定系統代理:
                Pac 模式：系統設定 pac 代理 (設定->網路->WIFI->詳細資訊->代理->自動代理設定)
                Global 模式：系統設定 http/socks 代理 (設定->網路->WIFI->詳細資訊->代理->HTTP,HTTPS 和 SOCKS 代理)
                Manual 模式：手動模式，不設定系統代理 (會清理系統代理，包括 pac,HTTP,HTTPS,SOCKS 代理)
                說明: 以上主要是以瀏覽器等系統級應用會走系統代理，其他應用通常需要手動設定代理。
                """),
                QAItem(question: "運行模式與路由的關係", answer: """
                運行模式決定了系統代理的設定方式，而路由規則則決定哪些流量透過代理伺服器，哪些流量直連。兩者結合使用，可以實現靈活的網路存取策略。
                """),
                QAItem(question: "路由匹配優先順序", answer: """
                路由匹配優先順序: 網域封鎖 -> 網域代理 -> 網域直連 -> IP 封鎖 -> IP 代理 -> IP 直連
                """),
                QAItem(question: "如何實現真正的全域代理？", answer: """
                預設情況下，除了瀏覽器外的應用通常需要手動設定代理。如果想實現真正的全域代理，可以考慮使用第三方工具如 Proxifier 來強制所有應用走代理。
                """),
                QAItem(question: "如何手動更新 core", answer: """
                可以手動下載 xray-core 對應系統架構版本，替換到 ~/.V2rayU/v2ray-core/ 目錄下，請注意，需要將 core 檔案名稱更改為 ~/.V2rayU/v2ray-core/v2ray
                """),
            ]
        default:
            return [
                QAItem(question: "How does V2rayU work?", answer: """
                V2rayU is a macOS application based on the V2Ray core, providing a graphical interface to simplify V2Ray configuration and management. It uses launchd to start and manage the V2Ray process and sets the system proxy to enable proxy internet access.
                """),
                QAItem(question: "Where are the configuration files stored?", answer: """
                V2rayU stores its configuration files in the ~/.V2rayU/ directory in the user's home folder (~ represents the username). You can run `ls -al ~/.V2rayU/` in the terminal to view the details.
                
                File descriptions:
                ~/.V2rayU/config.json - Main v2ray-core configuration file
                ~/.V2rayU/V2rayUTool - IMPORTANT!!! Helper tool for system proxy settings, must have -rwsrwsrwx 1 root admin permissions
                ~/.V2rayU/.V2rayU.db - SQLite database (version 5.0+), stores subscriptions and server information
                ~/.V2rayU/v2ray-core/v2ray - Executable v2ray-core binary, must match system architecture (x86_64 or arm64)
                ~/.V2rayU/proxy.js - Auto proxy configuration file for PAC mode
                ~/.V2rayU/v2ray-core.log - v2ray-core log file
                """),
                QAItem(question: "Operation modes explained", answer: """
                Mainly about how the system proxy is set:
                Pac mode: Auto proxy configuration (settings->Network->WIFI->Details->Proxy->Auto Proxy Configuration)
                Global mode: Global proxy, sets system HTTP/HTTPS/SOCKS proxy (settings->Network->WIFI->Proxy->HTTP,HTTPS,SOCKS Proxy)
                Manual mode: Clear system proxy settings, including auto proxy configuration URL, HTTP, HTTPS and SOCKS proxy
                Note: The above mainly affects browsers and other system-level applications that use the system proxy;
                """),
                QAItem(question: "Relationship between operation mode and routing", answer: """
                The operation mode determines how the system proxy is configured, while routing rules decide which traffic goes through the proxy server and which goes directly. Together, they enable flexible network access strategies.
                """),
                QAItem(question: "Routing priority", answer: """
                Routing priority: Domain block -> Domain proxy -> Domain direct -> IP block -> IP proxy -> IP direct
                """),
                QAItem(question: "How to achieve a true global proxy?", answer: """
                By default, applications other than browsers usually require manual proxy configuration. To achieve a true global proxy, you can use third-party tools such as Proxifier to force all applications to go through the proxy.
                """),
                QAItem(question: "How to manually update the core", answer: """
                You can manually download the xray-core version that matches your system architecture and replace it in the ~/.V2rayU/v2ray-core/ directory. Make sure to rename the core file to ~/.V2rayU/v2ray-core/v2ray
                """),
            ]
        }
    }
    
    var body: some View {
        ScrollView {
            VStack() {
                ForEach(items.indices, id: \.self) { idx in
                    let item = items[idx]

                    VStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.78, blendDuration: 0)) {
                                if expandedIndices.contains(idx) {
                                    expandedIndices.remove(idx)
                                } else {
                                    expandedIndices.insert(idx)
                                }
                            }
                        }) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: expandedIndices.contains(idx) ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.accentColor)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.question)
                                        .font(.headline)
                                        .foregroundColor(Color.primary)
                                    if !expandedIndices.contains(idx) {
                                        Text(item.answer)
                                            .font(.subheadline)
                                            .foregroundColor(Color.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle()) // 让空白区域也参与点击
                            .onTapGesture {
                                if expandedIndices.contains(idx) {
                                    expandedIndices.remove(idx)
                                } else {
                                    expandedIndices.insert(idx)
                                }
                            }
                            .padding()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(item.question)

                        if expandedIndices.contains(idx) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(item.answer)
                                    .font(.body)
                                    .foregroundColor(Color.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding([.horizontal, .bottom])
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.windowBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.08)))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            // 语言变更时折叠所有项，避免内容错位
            withAnimation { expandedIndices.removeAll() }
        }
    }
}
