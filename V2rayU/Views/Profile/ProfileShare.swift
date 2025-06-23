//
//  ConfigList.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

struct ProfileShareView: View {
    var profile: ProfileModel?
    var profiles: [ProfileModel] = []
    var isAll: Bool
    var onClose: () -> Void
    @State private var shareUris: [String] = []
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var currentQRCode: NSImage? = nil
    @State private var selectedUriIndex: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(isAll ? "Share All Proxies" : "Share Proxy")
                    .font(.title2).bold()
                Spacer()
                Button("Generate Share Link") {
                    generateShareLinks()
                }
                .buttonStyle(.borderedProminent)

                Button(action: onClose) {
                    Text("Close")
                }
            }
            .padding([.top, .horizontal], 20)
            .padding(.bottom, 8)

            Divider()

            if let p = profile {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Remark: \(p.remark)")
                        .font(.subheadline)
                    Text("Protocol: \(p.protocol.rawValue), Address: \(p.address):\(p.port)")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                Divider().padding(.top, 8)
            } else if isAll {
                Text("This will Share all proxies and show the result log.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                Divider().padding(.top, 8)
            }

            // 将原有的滚动区域高度调整，为二维码留出空间
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.textBackgroundColor))
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            if shareUris.isEmpty {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gray.opacity(0.2))
                                    Spacer()
                                }.padding(.top, 30)
                                Spacer()
                            } else {
                                ForEach(shareUris.indices, id: \.self) { idx in
                                    HStack {
                                        Text(shareUris[idx])
                                            .font(.system(size: 13, design: .monospaced))
                                            .foregroundColor(selectedUriIndex == idx ? .accentColor : .primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .lineLimit(1)
                                            .id(idx)
                                            .onTapGesture {
                                                selectedUriIndex = idx
                                                generateQRCode(from: shareUris[idx])
                                            }

                                        Button(action: {
                                            copyToClipboard(shareUris[idx])
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .foregroundColor(.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Copy to clipboard")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .onAppear {
                        scrollProxy = proxy
                        if !shareUris.isEmpty {
                            generateQRCode(from: shareUris[0])
                        }
                    }
                }
                .frame(minHeight: 100, maxHeight: 120)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // 添加二维码显示区域
            if !shareUris.isEmpty {
                VStack {
                    if let qrImage = currentQRCode {
                        Image(nsImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 160, height: 160)
                    } else {
                        ProgressView()
                            .frame(width: 160, height: 160)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                if !shareUris.isEmpty {
                    Button(action: {
                        copyToClipboard(shareUris.joined(separator: "\n"))
                    }) {
                        Label("Copy All", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(width: 560, height: 380)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 2)
        )
        .onAppear {
            shareUris.removeAll()
            generateShareLinks()
        }
    }

    private func generateShareLinks() {
        shareUris.removeAll()
        currentQRCode = nil
        selectedUriIndex = 0

        if isAll {
            // 分享所有配置
            for profile in profiles {
                if let uri = generateUri(profile) {
                    shareUris.append(uri)
                }
            }
        } else if let p = profile {
            // 分享单个配置
            if let uri = generateUri(p) {
                shareUris.append(uri)
            }
        }

        // 如果有滚动代理，滚动到顶部
        if let proxy = scrollProxy {
            proxy.scrollTo(0, anchor: .top)
        }

        // 生成第一个链接的二维码
        if !shareUris.isEmpty {
            generateQRCode(from: shareUris[0])
        }
    }

    private func generateQRCode(from string: String) {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return }

        let data = string.data(using: .utf8, allowLossyConversion: false)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledCiImage = ciImage.transformed(by: transform)

        let rep = NSCIImageRep(ciImage: scaledCiImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)

        currentQRCode = nsImage
    }

    private func generateUri(_ profile: ProfileModel) -> String? {
        let uri = ShareUri.generateShareUri(item: profile)
        if !uri.isEmpty {
            return uri
        }
        return nil
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
