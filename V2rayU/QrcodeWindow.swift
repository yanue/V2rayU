//
// Created by yanue on 2018/11/24.
// Copyright (c) 2018 yanue. All rights reserved.
//

import Cocoa
import Cocoa
import QRCoder

class QrcodeWindowController: NSWindowController {
    override var windowNibName: String? {
        return "QrcodeWindow" // no extension .xib here
    }
    @IBOutlet weak var shareUri: NSTextField!
    @IBOutlet weak var shareQrcode: NSImageView!

    func setShareUri(uri: String) {
        self.shareUri.stringValue = uri
        let generator = QRCodeGenerator()
        shareQrcode.image = generator.createImage(value: uri, size: CGSize(width: 256, height: 256))
    }
}
