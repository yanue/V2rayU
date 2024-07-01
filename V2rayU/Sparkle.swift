//
//  Sparkle.swift
//  V2rayU
//
//  Created by yanue on 2024/5/31.
//  Copyright © 2024 yanue. All rights reserved.
//

import Foundation
import Sparkle

class V2rayUpdaterController: NSObject, SPUUpdaterDelegate {
    private let primaryFeedURL = "https://v2rayu-61f76.web.app/appcast.xml"
    private let backupFeedURL = "https://raw.githubusercontent.com/yanue/V2rayU/master/appcast.xml"
    private var usePrimaryFeedURL = true
    private var updater: SPUUpdater?

    override init() {
        super.init()
        let userDriver = SPUStandardUserDriver(hostBundle: Bundle.main, delegate: nil)
        updater = SPUUpdater(hostBundle: Bundle.main, applicationBundle: Bundle.main, userDriver: userDriver, delegate: self)
    }

    func checkForUpdates() {
        // check version by github release
//        checkV2rayUVersion()
        // check by sparkle
        fetchAppcast(from: primaryFeedURL) { success in
            // 主线程
            DispatchQueue.main.async {
                if success {
                    self.usePrimaryFeedURL = true
                    self.startUpdateProcess()
                } else {
                    self.fetchAppcast(from: self.backupFeedURL) { success in
                        // 主线程
                        DispatchQueue.main.async {
                            if success {
                                self.usePrimaryFeedURL = false
                                self.startUpdateProcess()
                            } else {
                                print("Failed to fetch appcast from both primary and backup URLs.")
                            }
                        }
                    }
                }
            }
        }
    }

    private func fetchAppcast(from urlString: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Failed to fetch appcast: \(error)")
                completion(false)
                return
            }
            guard data != nil else {
                print("No data received from appcast URL")
                completion(false)
                return
            }
            // 解析 appcast 数据，确保它是有效的
            completion(true)
        }
        task.resume()
    }

    private func startUpdateProcess() {
        guard let updater = updater else { return }
        do {
            try updater.start()
            updater.checkForUpdates()
        } catch {
            print("Failed to start updater or check for updates: \(error)")
        }
    }

    // SPUUpdaterDelegate 方法实现
    func feedURLString(for updater: SPUUpdater) -> String? {
        return usePrimaryFeedURL ? primaryFeedURL : backupFeedURL
    }
}
