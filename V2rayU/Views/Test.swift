import SwiftUI

struct MissionControlView: View {
    @State private var windows: [WindowModel] = [
        WindowModel(id: UUID(), title: "Window 1", offset: .zero),
        WindowModel(id: UUID(), title: "Window 2", offset: .zero)
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            ForEach(windows) { window in
                WindowCardView(window: window)
                    .position(window.position)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                updateWindowPosition(window, by: value.translation)
                            }
                    )
            }
            
            VStack {
                Spacer()
                HStack {
                    Button(action: addWindow) {
                        Label("Add Window", systemImage: "plus")
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(8)
                    }
                    Button(action: resetWindows) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
    }
    
    private func updateWindowPosition(_ window: WindowModel, by translation: CGSize) {
        if let index = windows.firstIndex(where: { $0.id == window.id }) {
            windows[index].offset = CGSize(
                width: windows[index].offset.width + translation.width,
                height: windows[index].offset.height + translation.height
            )
        }
    }
    
    private func addWindow() {
        let newWindow = WindowModel(id: UUID(), title: "New Window", offset: .zero)
        windows.append(newWindow)
    }
    
    private func resetWindows() {
        windows = windows.map { window in
            var copy = window
            copy.offset = .zero
            return copy
        }
    }
}

struct WindowModel: Identifiable {
    let id: UUID
    var title: String
    var offset: CGSize
    var position: CGPoint {
        CGPoint(x: 200 + offset.width, y: 200 + offset.height)
    }
}

struct WindowCardView: View {
    var window: WindowModel
    
    var body: some View {
        VStack {
            Text(window.title)
                .font(.headline)
                .padding()
            Spacer()
        }
        .frame(width: 200, height: 150)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

struct MissionControlView_Previews: PreviewProvider {
    static var previews: some View {
        MissionControlView()
    }
}
