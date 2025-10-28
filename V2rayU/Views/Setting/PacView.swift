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
                    localized(.PacSettings)
                        .font(.title2)
                    localized(.ConfigureProxyRules)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { viewPacFile(self) }) {
                    Label(String(localized: .ViewPACFile), systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()

            VStack(alignment: .leading) {
                localized(.GFWListDownloadURL)
                    .font(.headline)
                TextField(String(localized: .EnterGFWListURL), text: $gfwPacListUrl)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            Spacer()

            VStack(alignment: .leading) {
                localized(.CustomRules)
                    .font(.headline)
                localized(.AddCustomRules)
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $pacUserRules)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
            }

            HStack {
                Button(action: { viewPacFile(self) }) {
                    Label(String(localized: .ViewPACFile), systemImage: "doc.text")
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
                    Label(String(localized: .UpdatePAC), systemImage: "arrow.triangle.2.circlepath")
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
            Alert(title: Text(String(localized: .PACUpdateNotification)), message: Text(tips), dismissButton: .default(Text("确定")))
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

    /// 更新 PAC 文件（由用户规则触发）
    func updatePac(_ sender: Any) {
        tips = String(localized: .UpdatingPacRules) // Updating Pac Rules ...

        do {
            // 保存用户规则
            logger.info("user-rules: \(pacUserRules)")
            try pacUserRules.write(toFile: PACUserRuleFilePath, atomically: true, encoding: .utf8)

            // 从 GFWList 更新
            UpdatePACFromGFWList(gfwPacListUrl: gfwPacListUrl)

            if GeneratePACFile(rewrite: true) {
                tips = String(localized: .PacUpdatedByUserRules) // PAC has been updated by User Rules.
            } else {
                tips = String(localized: .PacUpdateFailedByUserRules) // It's failed to update PAC by User Rules.
            }
            showAlert = true

        } catch {
            logger.info("updatePac error \(error)")
            // 使用本地化模板字符串
            tips = String(localized: .UpdatePacError, defaultValue: "updatePac error \(error)")
            showAlert = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.tips = ""
        }
    }

    /// 从 GFWList 在线地址更新
    func UpdatePACFromGFWList(gfwPacListUrl: String) {
        if !FileManager.default.fileExists(atPath: PACRulesDirPath) {
            try? FileManager.default.createDirectory(atPath: PACRulesDirPath, withIntermediateDirectories: true)
        }

        guard let reqUrl = URL(string: gfwPacListUrl) else {
            DispatchQueue.main.async {
                self.tips = String(localized: .InvalidGfwUrl)
                self.showAlert = true
            }
            return
        }

        let session = URLSession(configuration: getProxyUrlSessionConfigure())
        let task = session.dataTask(with: URLRequest(url: reqUrl)) { (data, _, error) in
            if let error {
                DispatchQueue.main.async {
                    self.tips = "\(String(localized: .GfwListDownloadError)): \(error.localizedDescription)")
                    self.showAlert = true
                }
                return
            }

            guard let data, let outputStr = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self.tips = String(localized: .GfwListDownloadFailed)
                    self.showAlert = true
                }
                Task {
                    await tryDownloadByShell(gfwPacListUrl: gfwPacListUrl)
                }
                return
            }

            do {
                try outputStr.write(toFile: GFWListFilePath, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    self.tips = String(localized: .GfwListUpdated) // gfwList has been updated
                    self.showAlert = true
                }

                UserDefaults.set(forKey: .gfwPacListUrl, value: gfwPacListUrl)

                if GeneratePACFile(rewrite: true) {
                    DispatchQueue.main.async {
                        self.tips = String(localized: .PacUpdatedByGfwList)
                        self.showAlert = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.tips = String(localized: .GfwListWriteFailed)
                    self.showAlert = true
                }
            }
        }

        task.resume()
    }

    func tryDownloadByShell(gfwPacListUrl: String) {
        let sockPort = getSocksProxyPort()
        let curlCmd = "cd \(PACRulesDirPath) && /usr/bin/curl -o gfwlist.txt \(gfwPacListUrl) -x socks5://127.0.0.1:\(sockPort)"
        logger.info("curlCmd: \(curlCmd)")

        let msg = shell(launchPath: "/bin/bash", arguments: ["-c", curlCmd])
        logger.info("curl result: \(msg)")

        if GeneratePACFile(rewrite: true) {
            self.tips = String(localized: .PacUpdatedByGfwList)
        } else {
            self.tips = String(localized: .PacUpdateFailedByCurl)
        }
        self.showAlert = true
    }
}
