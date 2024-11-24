import SwiftUI

struct AppMenuView: View {
    @State private var isOverrideEnabled = false
    @State private var isRewriteEnabled = false
    @State private var isMitMEnabled = false
    @State private var isScriptEnabled = false
    var openContentViewWindow: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            
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
        }
        .padding()
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

#Preview {
    AppMenuView(openContentViewWindow: vold)
}
