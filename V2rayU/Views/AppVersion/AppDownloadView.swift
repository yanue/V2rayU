import SwiftUI

/// 🎯 下载及安装页面的 ViewModel
class AppDownloadViewModel: ObservableObject {
    @Published var progressText = "Downloading..."
    @Published var dmgUrl: String = ""
    @Published var progress: Float = 0.0
    @Published var isDownloading: Bool = false

    var onCancel: (() -> Void)?
    var onInstall: (() -> Void)?

    func cancel() { onCancel?() }
    func install() { onInstall?() }
}

/// 🖼️ 下载安装界面视图
struct AppDownloadView: View {
    @ObservedObject var viewModel: AppDownloadViewModel

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image("V2rayU")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .cornerRadius(8)

                Spacer()

                VStack {
                    ProgressView(value: viewModel.progress, total: 100) {
                        Text(viewModel.progressText)
                    }

                    HStack {
                        Spacer()
                        if viewModel.isDownloading {
                            Button("Cancel") { viewModel.cancel() }
                        } else {
                            Button("Install V2rayU") { viewModel.install() }
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 400, height: 200)
    }
}
