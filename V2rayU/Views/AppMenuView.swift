import SwiftUI

struct AppMenuView: View {
    @ObservedObject var appState = AppState.shared // 引用单例

    var openContentViewWindow: () -> Void

    var body: some View {
        VStack() {
            HeaderView()
            MenuSpeedView()
            MenuRoutingPanel()
            MenuProfilePanel()
            MenuItemsView(openContentViewWindow: openContentViewWindow)
        }
        .padding(12)
        .frame(maxHeight: .infinity)
        .frame(width: 340)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8)) // 背景颜色透明度.7
    }
}

// 预览修正
enum Dummy { static func open() {} }
#Preview {
    AppMenuView(openContentViewWindow: Dummy.open)
}
