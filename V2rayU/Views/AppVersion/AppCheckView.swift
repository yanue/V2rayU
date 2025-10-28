import SwiftUI

/// 🎯 ViewModel for AppCheckController
/// 管理“检查更新”页面的数据状态和行为。
class AppCheckViewModel: ObservableObject {
    /// 当前进度文本
    @Published var progressText: String = "Check for updates..."

    /// 关闭页面事件回调，由 Controller 注入
    var onClose: (() -> Void)?

    /// 请求更新逻辑回调，由 Controller 绑定
    var onCheckUpdates: (() -> Void)?

    /// 点击“Cancel”按钮时触发
    func cancel() {
        onClose?()
    }

    /// 主动触发检查更新逻辑
    func checkForUpdates() {
        onCheckUpdates?()
    }
}

/// 🖼️ SwiftUI 视图层 - 仅负责界面展示
struct AppCheckView: View {
    @ObservedObject var viewModel: AppCheckViewModel

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image("V2rayU")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .cornerRadius(8)

                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(viewModel.progressText)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding(.horizontal)

                    HStack {
                        Spacer()
                        Button("Cancel") {
                            viewModel.cancel()
                        }
                        .padding(.trailing, 20)
                    }
                }
            }
            .padding()
        }
        .frame(width: 400, height: 200)
    }
}
