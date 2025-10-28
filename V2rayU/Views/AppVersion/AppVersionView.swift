import SwiftUI

/// 🎯 ViewModel for AppVersionController
/// 负责展示新版本信息与用户选择（跳过 / 安装）
class AppVersionViewModel: ObservableObject {
    @Published var title = "A new version of V2rayU is available!"
    @Published var description = ""
    @Published var releaseNotes = ""
    @Published var releaseNotesTitle = "Release Notes:"
    @Published var skipVersionText = "Skip This Version"
    @Published var installText = "Install Update"

    /// 点击“跳过”回调
    var onSkip: (() -> Void)?
    /// 点击“安装”回调
    var onInstall: (() -> Void)?
}

/// 🖼️ 新版本详情页面视图
struct AppVersionView: View {
    @ObservedObject var viewModel: AppVersionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image("V2rayU")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .padding(.top, 20)
                    .padding(.leading, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.title)
                        .font(.headline)
                        .padding(.top, 20)

                    Text(viewModel.description)
                        .padding(.trailing, 20)

                    Text(viewModel.releaseNotesTitle)
                        .font(.headline)
                        .bold()
                        .padding(.top, 20)

                    TextEditor(text: $viewModel.releaseNotes)
                        .lineSpacing(6)
                        .frame(height: 120)
                        .border(Color.gray, width: 1)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Button(viewModel.skipVersionText) { viewModel.onSkip?() }
                        Spacer()
                        Button(viewModel.installText) { viewModel.onInstall?() }
                            .padding(.trailing, 20)
                            .keyboardShortcut(.defaultAction)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(width: 500, height: 300)
    }
}
