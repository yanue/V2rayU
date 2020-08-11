//
//  V2rayCore.swift
//  V2rayU
//
//  Created by yanue on 2018/10/12.
//  Copyright © 2018 yanue. All rights reserved.
//

import Alamofire
import SwiftyJSON

// v2ray-core version check, download, unzip
class V2rayCore {
    static let version = "v4.27.0"
    // need replace ${version}
    var releaseUrl: String = "https://github.com/v2ray/v2ray-core/releases/download/${version}/v2ray-macos-64.zip"
    // lastet release verison info
    let versionUrl: String = "https://api.github.com/repos/v2ray/v2ray-core/releases/latest"

    func checkLocal(hasNewVersion: Bool) {
        // has new verion
        if hasNewVersion {
            // download new version
            self.download()
            return
        }

        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: v2rayCoreFile) {
            self.download();
        }
    }

    func check() {
        // 当前版本检测
        let oldVersion = UserDefaults.get(forKey: .v2rayCoreVersion) ?? V2rayCore.version

        Alamofire.request(versionUrl).responseJSON { response in
            var hasNewVersion = false

            defer {
                // check local file
                self.checkLocal(hasNewVersion: hasNewVersion)
            }

            //to get status code
            if let status = response.response?.statusCode {
                if status != 200 {
                    NSLog("error with response status: ", status)
                    return
                }
            }

            //to get JSON return value
            if let result = response.result.value {
                let JSON = result as! NSDictionary

                // get tag_name (verion)
                guard let tag_name = JSON["tag_name"] else {
                    NSLog("error: no tag_name")
                    return
                }

                // get prerelease and draft
                guard let prerelease = JSON["prerelease"], let draft = JSON["draft"] else {
                    // get
                    NSLog("error: get prerelease or draft")
                    return
                }

                // not pre release or draft
                if prerelease as! Bool == true || draft as! Bool == true {
                    NSLog("this release is a prerelease or draft")
                    return
                }

                let newVersion = tag_name as! String

                // get old versiion
                let oldVer = oldVersion.replacingOccurrences(of: "v", with: "").versionToInt()
                let curVer = newVersion.replacingOccurrences(of: "v", with: "").versionToInt()

                // compare with [Int]
                if oldVer.lexicographicallyPrecedes(curVer) {
                    // store this version
                    UserDefaults.set(forKey: .v2rayCoreVersion, value: newVersion)
                    // has new version
                    hasNewVersion = true
                    NSLog("has new version", newVersion)
                }

                return
            }
        }
    }

    func download() {
        let version = UserDefaults.get(forKey: .v2rayCoreVersion) ?? "v4.20.0"
        let url = releaseUrl.replacingOccurrences(of: "${version}", with: version)
        NSLog("start download", version)

        // check unzip sh file
        // path: /Application/V2rayU.app/Contents/Resources/unzip.sh
        guard let shFile = Bundle.main.url(forResource: "unzip", withExtension: "sh") else {
            NSLog("unzip shell file no found")
            return
        }

        // download file: /Application/V2rayU.app/Contents/Resources/v2ray-macos.zip
        let fileUrl = URL.init(fileURLWithPath: shFile.path.replacingOccurrences(of: "/unzip.sh", with: "/v2ray-macos.zip"))
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            return (fileUrl, [.removePreviousFile, .createIntermediateDirectories])
        }

        let utilityQueue = DispatchQueue.global(qos: .utility)
        Alamofire.download(url, to: destination)
                .downloadProgress(queue: utilityQueue) { progress in
                    NSLog("已下载：\(progress.completedUnitCount / 1024)KB")
                }
                .responseData { response in
                    switch response.result {
                    case .success(_):
                        break
                    case .failure(_):
                        NSLog("error with response status:")
                        return
                    }

                    if let _ = response.result.value {
                        // make unzip.sh execable
                        // chmod 777 unzip.sh
                        let execable = "cd " + AppResourcesPath + " && /bin/chmod 777 ./unzip.sh"
                        _ = shell(launchPath: "/bin/bash", arguments: ["-c", execable])

                        // unzip v2ray-core
                        // cmd: /bin/bash -c 'cd path && ./unzip.sh '
                        let sh = "cd " + AppResourcesPath + " && ./unzip.sh && /bin/chmod -R 777 ./v2ray-core"
                        // exec shell
                        let res = shell(launchPath: "/bin/bash", arguments: ["-c", sh])
                        NSLog("res:", sh, res!)
                    }
                }
    }
}
