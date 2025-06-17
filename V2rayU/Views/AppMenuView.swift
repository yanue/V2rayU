import SwiftUI

struct AppMenuView: View {
    @ObservedObject var appState = AppState.shared // 引用单例

    var openContentViewWindow: () -> Void

    var body: some View {
        VStack {
            HeaderView()
            Spacer()
            MenuSpeedView()
            Spacer()
            MenuRoutingPanel()
            Spacer()
            MenuProfilePanel()
            Spacer()
            MenuItemsView(openContentViewWindow: openContentViewWindow)
            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
        .frame(width: 320)

    }
}


#Preview {
    AppMenuView(openContentViewWindow: vold)
}
