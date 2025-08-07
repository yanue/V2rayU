import SwiftUI

// MARK: - 状态栏视图

struct StatusItemView: View {
    @ObservedObject var appState = AppState.shared // 显式使用 ObservedObject
    @ObservedObject var settings = AppSettings.shared // 显式使用 ObservedObject

    var body: some View {
        HStack() {
            // 应用图标
            Image(appState.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            if settings.showSpeedOnTray {
                // 速度信息（两行显示）
                VStack(alignment: .leading) {
                    Text("↓ \(String(format: "%.0f", appState.proxyDownSpeed)) KB/s")
                    Text("↑ \(String(format: "%.0f", appState.proxyUpSpeed)) KB/s")
                }
                .font(.system(size: 9))
                .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .fixedSize()   // StatusBar自适应关键点: 需要 StatusItemView 设置 fixedSize 配合 statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }
}


struct CoreStatusItemView: View {
    @ObservedObject var appState = AppState.shared // 显式使用 ObservedObject
    @ObservedObject var settings = AppSettings.shared // 显式使用 ObservedObject

    var body: some View {
        HStack() {
            // 应用图标
            Image(appState.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            if settings.showSpeedOnTray {
                // 速度信息（两行显示）
                VStack(alignment: .leading) {
                    Text("↓ \(String(format: "%.0f", appState.proxyDownSpeed)) KB/s")
                    Text("↑ \(String(format: "%.0f", appState.proxyUpSpeed)) KB/s")
                }
                .font(.system(size: 9))
                .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .fixedSize()   // StatusBar自适应关键点: 需要 StatusItemView 设置 fixedSize 配合 statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }
}

