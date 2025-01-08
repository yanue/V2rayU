import SwiftUI

struct AppMenuView: View {
    @ObservedObject var appState = AppState.shared // 引用单例

    // 保存选中的子项
    @State private var selectedItem: String? = nil
    @State private var listHeight: CGFloat = 0 // 保存列表高度
    @State private var isExpanded: Bool = false // 保存列表高度
    @State private var isEnabled = false

    var openContentViewWindow: () -> Void
    @State private var selectedOption = 1
    
    var body: some View {
        VStack {
            HeaderView()
            if appState.v2rayTurnOn {
                MenuSpeedView()
            }

            MenuRoutingPanel()

            MenuProfilePanel()

            VStack(alignment: .leading) {
                MenuItemView(title: "打开设置", action: openContentViewWindow)
                Divider()
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
                MenuItemView(title: "Quit", action: { NSApplication.shared.terminate(nil) })
            }
            .cornerRadius(6)
            .padding()
        }.frame(maxHeight: .infinity)
            .frame(width: 360)
//            .background(.regularMaterial) // 毛玻璃效果
//            .foregroundColor(.primary)
//            .animation(nil, value: isExpanded) // 关闭展开/折叠动画
    }
}


#Preview {
    AppMenuView(openContentViewWindow: vold)
}
