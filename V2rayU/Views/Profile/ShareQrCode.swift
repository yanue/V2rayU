//
//  ConfigList.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

struct ShareQrCodeView: View {
    @ObservedObject var profile: ProfileModel
    @State private var shareUri: String = ""
    @State private var currentQRCode: NSImage? = nil
    @State private var generated = false
    @State private var copyed = false
    var onClose: () -> Void

    var body: some View {
        VStack() {
            HStack {
                LocalizedTextLabelView(label: .ShareQrCode)
                    .font(.title2).bold()
                Spacer()
                
                Button(action: generate) {
                    if generated {
                        LocalizedTextLabelView(label: .Regenerated)
                    } else {
                        LocalizedTextLabelView(label: .Regenerate)
                    }
                }
                
                Button(action: copyToClipboard) {
                    if copyed {
                        LocalizedTextLabelView(label: .Copied)
                    } else {
                        LocalizedTextLabelView(label: .Copy)
                    }
                }
                
                Button(action: onClose) {
                    LocalizedTextLabelView(label: .Close)
                }
            }

            Divider()

            // 本地化：组合 Remark / Protocol / Address 标签
            let remarkLabel = String(localized: .Remark)
            let protocolLabel = String(localized: .`Protocol`)
            let addressLabel = String(localized: .Address)
            Text("\(remarkLabel): \(profile.remark), \(protocolLabel): \(profile.`protocol`.rawValue), \(addressLabel): \(profile.address):\(profile.port)")
                        
            VStack {
                TextEditor(text: $shareUri)
                    .font(.system(.body, design: .monospaced))
            }
            .frame(height: 60)
            .background() // 2. 然后背景
            .clipShape(RoundedRectangle(cornerRadius: 8)) // 3. 内圆角
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    .shadow(color: Color.primary.opacity(0.1), radius: 1, x: 0, y: 1)
            ) // 4. 添加边框和阴影
            
            // 添加二维码显示区域
            VStack {
                if let qr = currentQRCode {
                    Image(nsImage: qr)
                       .resizable()
                       .scaledToFit()
                       .frame(width: 200, height: 200)
                } else {
                    ProgressView()
                        .frame(width: 200, height: 200)
                }
            }
        }
        .frame(width: 560)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 2)
        )
        .onAppear() {
            regenerate()
        }
    }
   
    private func generate() {
        if generated {
            return
        }
        generated = true // 先隐藏
        regenerate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            generated = false // 再淡入
        }
    }
    
    func regenerate() {
        shareUri = ShareUri.generateShareUri(item: profile.toEntity())
        currentQRCode = generateQRCode(from: shareUri)
        logger.debug("regenerate: \(self.shareUri)")
    }

    private func copyToClipboard() {
        if copyed {
            return
        }
        copyed = true
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(shareUri, forType: .string)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copyed = false // 再淡入
        }
    }
    
    private func generateQRCode(from string: String) -> NSImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }
        let data = string.data(using: .utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else {
            return nil
        }
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let rep = NSCIImageRep(ciImage: scaled)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
    
}
