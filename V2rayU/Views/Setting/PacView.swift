//
//  PacView.swift
//  V2rayU
//
//  Created by yanue on 2025/7/20.
//

import SwiftUI

struct PacView: View {
    @State private var tips: String = ""
    @State private var gfwPacListUrl: String = ""
    @State private var pacFileUrl: URL? = nil
    @State private var pacUserRules: String = ""
    @State private var showAlert: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PAC 设置")
                        .font(.title2)
                    Text("配置代理规则，管理 GFWList 与自定义规则。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { viewPacFile(self) }) {
                    Label("查看 PAC 文件", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()

            VStack(alignment: .leading) {
                Text("GFW List 下载地址：")
                    .font(.headline)
                TextField("输入 GFW List URL", text: $gfwPacListUrl)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            Spacer()

            VStack(alignment: .leading) {
                Text("自定义规则：")
                    .font(.headline)
                Text("可在此添加自定义规则，每行一条。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $pacUserRules)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
            }

            HStack {
                Button(action: { viewPacFile(self) }) {
                    Label("查看 PAC 文件", systemImage: "doc.text")
                }
                .buttonStyle(.bordered)

                Spacer()

                if !tips.isEmpty {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.accentColor)
                        Text(tips)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: { updatePac(self) }) {
                    Label("更新 PAC", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear {
            // Load GFW List URL and PAC File Path from UserDefaults
            gfwPacListUrl = UserDefaults.get(forKey: .gfwPacListUrl, defaultValue: GFWListURL)
            // Load PAC File Content
            pacUserRules = getPacUserRules()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("提示"), message: Text(tips), dismissButton: .default(Text("确定")))
        }
    }

    func viewPacFile(_ sender: Any) {
        let pacUrl = getPacUrl()
        logger.info("viewPacFile PACUrl: \(pacUrl)")
        guard let url = URL(string: pacUrl) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func updatePac(_ sender: Any) {
        tips = "Updating Pac Rules ..."
        do {
            // save user rules into file
            logger.info("user-rules: \(pacUserRules)")
            try pacUserRules.write(toFile: PACUserRuleFilePath, atomically: true, encoding: .utf8)

            UpdatePACFromGFWList(gfwPacListUrl: gfwPacListUrl)

            if GeneratePACFile(rewrite: true) {
                // Popup a user notification
                tips = "PAC has been updated by User Rules."
                showAlert = true
            } else {
                tips = "It's failed to update PAC by User Rules."
                showAlert = true
            }
        } catch {
            logger.info("updatePac error \(error)")
            tips = "updatePac error \(error)"
            showAlert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.tips = ""
        }
    }

    func UpdatePACFromGFWList(gfwPacListUrl: String) {
        // Make the dir if rulesDirPath is not exesited.
        if !FileManager.default.fileExists(atPath: PACRulesDirPath) {
            do {
                try FileManager.default.createDirectory(atPath: PACRulesDirPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
            }
        }

        guard let reqUrl = URL(string: gfwPacListUrl) else {
            DispatchQueue.main.async {
                self.tips = "Failed to download latest GFW List: url is not valid"
                self.showAlert = true
            }
            return
        }

        // url request with proxy
        let session = URLSession(configuration: getProxyUrlSessionConfigure())
        let task = session.dataTask(with: URLRequest(url: reqUrl)) { (data: Data?, _: URLResponse?, error: Error?) in
            if error != nil {
                DispatchQueue.main.async {
                    self.tips = "Failed to download latest GFW List: \(String(describing: error))"
                    self.showAlert = true
                }
            } else {
                if data != nil {
                    if let outputStr = String(data: data!, encoding: String.Encoding.utf8) {
                        do {
                            try outputStr.write(toFile: GFWListFilePath, atomically: true, encoding: String.Encoding.utf8)
                            DispatchQueue.main.async {
                                self.tips = "gfwList has been updated"
                                self.showAlert = true
                            }

                            // save to UserDefaults
                            UserDefaults.set(forKey: .gfwPacListUrl, value: gfwPacListUrl)

                            if GeneratePACFile(rewrite: true) {
                                // Popup a user notification
                                DispatchQueue.main.async {
                                    self.tips = "PAC has been updated by latest GFW List."
                                    self.showAlert = true
                                }
                            }
                        } catch {
                            // Popup a user notification
                            DispatchQueue.main.async {
                                self.tips = "Failed to Write latest GFW List."
                                self.showAlert = true
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.tips = "Failed to download latest GFW List."
                            self.showAlert = true
                        }
                    }
                } else {
                    // Popup a user notification
                    DispatchQueue.main.async {
                        self.tips = "Failed to download latest GFW List."
                        self.showAlert = true
                    }
                    Task {
                        await tryDownloadByShell(gfwPacListUrl: gfwPacListUrl)
                    }
                }
            }
        }
        task.resume()
    }

    func tryDownloadByShell(gfwPacListUrl: String) {
        let sockPort = getSocksProxyPort()
        let curlCmd = "cd " + PACRulesDirPath + " && /usr/bin/curl -o gfwlist.txt \(gfwPacListUrl) -x socks5://127.0.0.1:\(sockPort)"
        logger.info("curlCmd: \(curlCmd)")
        let msg = shell(launchPath: "/bin/bash", arguments: ["-c", curlCmd])
        if GeneratePACFile(rewrite: true) {
            // Popup a user notification
            DispatchQueue.main.async {
                self.tips = "PAC has been updated by latest GFW List."
            }
        }
    }
}
