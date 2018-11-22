//
// Created by yanue on 2018/11/22.
// Copyright (c) 2018 yanue. All rights reserved.
//

import Foundation
import CoreGraphics
import CoreImage

class Scanner {

    // scan from screen
    static func scanQRCodeFromScreen() -> String {
        var displayCount: UInt32 = 0;
        var result = CGGetActiveDisplayList(0, nil, &displayCount)
        if (Int(result.rawValue) != 0) {
            return ""
        }
        let allocated = Int(displayCount)
        let activeDisplays: UnsafeMutablePointer<UInt32> = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: allocated)

        result = CGGetActiveDisplayList(displayCount, activeDisplays, &displayCount)
        if (Int(result.rawValue) != 0) {
            return ""
        }

        var qrStr = ""

        for i in 0..<displayCount {
            let str = self.getQrcodeStr(displayID: activeDisplays[Int(i)])
            // support: ss:// | ssr:// | vmess://
            if str.contains("ss://") || str.contains("ssr://") || str.contains("vmess://") {
                qrStr = str
                break
            }
        }

        activeDisplays.deallocate()

        return qrStr
    }

    private static func getQrcodeStr(displayID: CGDirectDisplayID) -> String {
        guard let qrcodeImg = CGDisplayCreateImage(displayID) else {
            return ""
        }

        let detector: CIDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!
        let ciImage: CIImage = CIImage(cgImage: qrcodeImg)
        let features = detector.features(in: ciImage)

        var qrCodeLink = ""

        for feature in features as! [CIQRCodeFeature] {
            qrCodeLink += feature.messageString ?? ""
        }

        return qrCodeLink
    }
}
