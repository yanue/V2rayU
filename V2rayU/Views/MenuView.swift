import SwiftUI

struct AppMenuView: View {
    @State private var isOverrideEnabled = false
    @State private var isRewriteEnabled = false
    @State private var isMitMEnabled = false
    @State private var isScriptEnabled = false
    @State private var isPresenting  = false
    var openContentViewWindow: () -> Void
    var body: some View {
        VStack() {
            HStack(spacing: 10) {
                Image(systemName: "arrow.right.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("Rule Mode")
                        .font(.headline)
                    
                    Text("Outbound Mode")
                        .font(.subheadline)
                }
            }
            .padding(16)
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue]), startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(10)
            Button("Show Toast"){
                isPresenting.toggle()
            }
            HStack(spacing: 20) {
                Button("打开配置") {
                    openContentViewWindow()
                }
                createToggleView(image: "star.fill", text: "Override", isOn: $isOverrideEnabled)
                createToggleView(image: "hammer", text: "Rewrite", isOn: $isRewriteEnabled)
                createToggleView(image: "lock", text: "MitM", isOn: $isMitMEnabled)
                createToggleView(image: "f.square", text: "Script", isOn: $isScriptEnabled)
            }
            
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "bell.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("514.59 MB, 852.34 MB U T")
                            .font(.title)
                        
                        Text("Subscription Expired: 2022-09-26 13:09:20")
                            .font(.subheadline)
                    }
                }
                .padding(16)
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color.red, Color.orange]), startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(10)
                
                Text("2.00 TB")
                    .font(.title)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                MenuItemView(title: "Import Server From Pasteboard", action: {
                    if let uri = NSPasteboard.general.string(forType: .string), uri.count > 0 {
                        importUri(url: uri)
                    } else {
                        noticeTip(title: "import server fail", informativeText: "no found vmess:// or vless:// or trojan:// or ss:// from Pasteboard")
                    }
                })
                Divider()
                MenuItemView(title: "Scan QRCode From Screen", action: {
                    let uri: String = Scanner.scanQRCodeFromScreen()
                    if uri.count > 0 {
                        importUri(url: uri)
                    } else {
                        noticeTip(title: "import server fail", informativeText: "no found qrcode")
                    }
                })
                Divider()
                MenuItemView(title: "Quit", action: {NSApplication.shared.terminate(nil) })
            }
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(6)
            .padding()
        }
    }
    
    private func createToggleView(image: String, text: String, isOn: Binding<Bool>) -> some View {
        VStack(spacing: 10) {
            Image(systemName: image)
                .resizable()
                .frame(width: 30, height: 30)
            
            Toggle(isOn: isOn) {
                Text(text)
                    .font(.body)
            }
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)
        )
        .cornerRadius(10)
    }
}


struct MenuItemView: View {
    var title: String
    var action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(isHovered ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
            .background(isHovered ? Color.accentColor.opacity(0.8) : Color.clear) // 鼠标悬停高亮
            .cornerRadius(4) // 可选的圆角
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle()) // 去掉默认按钮样式
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    AppMenuView(openContentViewWindow: vold)
}
