import SwiftUI

struct CustomPicker<T: Identifiable & Equatable>: View {
    @Binding var selection: T
    let items: [T]
    let label: String
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack {
            Button(action: {
                isExpanded.toggle()

            }) {
                HStack {
                    Text(label)
                        .font(.headline)
                    Spacer()
                    Text("\(selection.id)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            if isExpanded {
                List(items) { item in
                    Button(action: {
                        selection = item
                        isExpanded = false

                    }) {
                        Text("\(item.id)") // Customize this based on your data type
                            .padding()
                    }
                }
                .frame(maxHeight: 200)
                .cornerRadius(8)
                .shadow(radius: 5)
//                .transition(.move(edge: .top))
            }
        }
    }
}
struct MyItem: Identifiable, Equatable {
    var id: String
}
struct AppMenuView: View {
    @ObservedObject var appState = AppState.shared // 引用单例

    var openContentViewWindow: () -> Void
    @State var selected: RunMode = .global
    @State private var selectedItem: MyItem = MyItem(id: "Item 1")

    let items: [MyItem] = [
          MyItem(id: "Item 1"),
          MyItem(id: "Item 2"),
          MyItem(id: "Item 3")
      ]
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
        .padding(.horizontal,8)
        .frame(maxHeight: .infinity)
            .frame(width: 320)

    }
}


#Preview {
    AppMenuView(openContentViewWindow: vold)
}
