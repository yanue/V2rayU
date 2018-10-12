//
//  V2rayCore.swift
//  V2rayU
//
//  Created by yanue on 2018/10/12.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

class V2rayCore {
//    init(){
//        self.download()
//    }
//
    private var jsonData: [String: Any] = [:]

    // need replace ${version}
    var releaseUrl:String = "https://github.com/v2ray/v2ray-core/releases/download/${version}/v2ray-macos.zip"
    // lastet release verison info
    let versionUrl:String = "https://api.github.com/repos/v2ray/v2ray-core/releases/latest"

    func checkVersion() {
        Alamofire.request(versionUrl).responseJSON { response in
            //to get status code
            if let status = response.response?.statusCode {
                if status != 200 {
                    print("error with response status: \(status)")
                    return
                }
            }
            
            //to get JSON return value
            if let result = response.result.value {
                let JSON = result as! NSDictionary

                // get tag_name (verion)
                guard let tag_name = JSON["tag_name"] else {
                    return
                }
                
                // get prerelease and draft
                guard let prerelease = JSON["prerelease"],let draft = JSON["draft"] else {
                    // get
                    print("err: get prerelease or draft")
                    return
                }
                
                // not pre release or draft
                if prerelease as! Bool == true || draft as! Bool == true {
                    print("this release is a prerelease or draft")
                    return
                }
                
                let currentVersion = tag_name as! String
                // store
//                UserDefaults.set(forKey: .v2rayCoreVersion, value: "v1.900")
                
                // get old versiion
                if let oldVersion = UserDefaults.get(forKey: .v2rayCoreVersion) {
                    let oldVer = oldVersion.replacingOccurrences(of: "v", with: "").versionToInt()
                    let curVer = currentVersion.replacingOccurrences(of: "v", with: "").versionToInt()
                    // compare with [Int]
                    if oldVer.lexicographicallyPrecedes(curVer) {
                        print("new version",currentVersion,oldVersion)
                    }
                }
                
                // store
                UserDefaults.set(forKey: .v2rayCoreVersion, value: currentVersion)
            }
        }
    }
  
    func download(){
        guard let version = UserDefaults.get(forKey: .v2rayCoreVersion) else {
            print("err get verion")
            return
        }
        
        let url = releaseUrl.replacingOccurrences(of: "${version}", with: version)
        
        // → /var/folders/v8/tft1q…/T/…-8DC6DD131DC1/report.pdf
        guard let tmp = try? TemporaryFile(creatingTempDirectoryForFilename: "v2ray-macos.zip") else {
            print("err get tmp")
            return
        }
        
        let fileURL = tmp.fileURL
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        let utilityQueue = DispatchQueue.global(qos: .utility)
        Alamofire.download(url,to:destination)
            .downloadProgress (queue: utilityQueue){ progress in
                print("已下载：\(progress.completedUnitCount/1024)KB")
            }
            .responseData { response in
                switch response.result {
                    case .success(_):
                        break
                    case .failure(_):
                        print("error with response status:")
                        return
                }
                
                if let data = response.result.value {
                    print("done.",data,fileURL)
                    
                }
            }
    }
    
    func unzip()  {
//        let a =  Bundle.main.resourcePath
//        print("Bundle.main.url",a)
        
        guard let shFile = Bundle.main.url(forResource: "unzip", withExtension:"sh") else {
            print("unzip shell file no found")
            return
        }
        
        
//        shFile.absoluteURL
        let res = shell(launchPath: shFile.absoluteString, arguments: [""])
        print("res",res!)
    }
    
}
